#!/usr/bin/env perl
# PODNAME: fetch-cthist-json.pl
# ABSTRACT: Retrives or updates historical Clinical Trials data

use strict;
use warnings;
use feature qw(say signatures postderef);
no warnings qw(experimental::signatures experimental::postderef);

BEGIN {
	require Env::Dot;
	Env::Dot->import unless $ENV{HARNESS_ACTIVE};
}
use Path::Tiny 0.144 qw(path);
use LWP::UserAgent ();
use LWP::Protocol::https ();
use Cpanel::JSON::XS ();
use List::Util qw(pairs unpairs any);
use List::UtilsBy qw(nmax_by);
use Type::Params 2.000 qw(signature_for);
use Types::Common qw(InstanceOf);
use Return::Type;

my $json = Cpanel::JSON::XS->new->utf8;

sub _log { say STDERR @_; }

####

package CTTypes {
	use Exporter::Shiny -setup => {
		exports => [qw(
			NCT_ID
			VersionNumber

			CTVersionsData_Change

			CTVersionsData
			CTStudyRecordData

			StudyRecord_JSONL
			StudyRecord_JSONL_Collection
		)],
	};
	use Types::Common qw(StrMatch Dict Slurpy HashRef ArrayRef PositiveOrZeroInt Maybe);

	## Basic types
	use constant {
		NCT_ID        => StrMatch[qr/ \A NCT [0-9]{8} \z /x ],
		VersionNumber => PositiveOrZeroInt
	};

	## From API
	use constant CTVersionsData_Change         => Dict[version => VersionNumber, Slurpy[HashRef] ];
	use constant {
		CTStudyRecordData => Dict[studyVersion => VersionNumber, study => HashRef],
		CTVersionsData    => Dict[changes => ArrayRef[CTVersionsData_Change]],
	};

	## Serialization
	# Individual line of JSON Lines
	use constant StudyRecord_JSONL => Dict[ change => CTVersionsData_Change, studyRecord => Maybe[CTStudyRecordData] ];
	# Type for collection of JSON Lines
	use constant StudyRecord_JSONL_Collection => ArrayRef[StudyRecord_JSONL];
}

package StudyRecords {
	use Moo;
	use List::Util 1.44 qw(uniqnum);
	use List::UtilsBy qw(nsort_by);
	use Type::Params 2.000 qw(signature_for);
	use Types::Common qw(Str Map InstanceOf);
	use Return::Type;
	use CTTypes qw(
		StudyRecord_JSONL_Collection
		VersionNumber
		CTVersionsData_Change

		CTVersionsData CTStudyRecordData
	);

	has change_map => ( is => 'rw', isa => Map[VersionNumber, CTVersionsData_Change], default => sub { +{} }, );
	has study_map  => ( is => 'rw', isa => Map[VersionNumber, CTStudyRecordData    ], default => sub { +{} }, );

	sub change_count($self) { 0 + keys $self->change_map->%* }
	sub change_versions($self) { [ sort { $a <=> $b } keys $self->change_map->%* ] }
	sub study_versions($self) { [ sort { $a <=> $b } map { $_->{studyVersion} } values $self->study_map->%* ] }

	signature_for add_change => (
		method => 1,
		pos => [ CTVersionsData_Change ]);
	sub add_change($self, $change) {
		$self->change_map->{ $change->{version} } = $change;
	}

	signature_for add_versions_data => (
		method => 1,
		pos => [ CTVersionsData ]);
	sub add_versions_data($self, $versions) {
		$self->add_change($_) for $versions->{changes}->@*;
	}

	signature_for add_study_record => (
		method => 1,
		pos => [ CTStudyRecordData ]);
	sub add_study_record($self, $study_record) {
		$self->study_map->{ $study_record->{studyVersion} } = $study_record;
	}

	signature_for FROM_JSON_LINES => (
		method => Str,
		pos => [ StudyRecord_JSONL_Collection ]);
	sub FROM_JSON_LINES :ReturnType(InstanceOf['StudyRecords']) ($class, $data) {
		my %change_map = map {
				$_->{change}{version} => $_->{change}
			} @$data;
		my %study_map  = map {
				defined $_->{studyRecord}
				? (
					$_->{studyRecord}{studyVersion} => $_->{studyRecord}
				) : ()
			} @$data;
		return $class->new(
			change_map => \%change_map,
			study_map  => \%study_map,
		);
	}

	signature_for TO_JSON_LINES => ( method => 1, pos => []);
	sub TO_JSON_LINES :ReturnType(StudyRecord_JSONL_Collection) ($self) {
		my @versions = uniqnum sort { $a <=> $b } (
			keys $self->change_map->%*,
			keys $self->study_map->%*
		);
		return [ map { +{
				change      => $self->change_map->{$_},
				studyRecord =>
					# make the undef explicit
					( exists $self->study_map->{$_}
					? $self->study_map->{$_}
					: undef
					),
			} } @versions ];
	};
}

package StudyRecords::Store {
	use Type::Params 2.000 qw(signature_for);
	use Types::Common qw(Str InstanceOf);
	use CTTypes qw( NCT_ID );
	use Path::Tiny 0.144 qw(path);
	use List::UtilsBy qw(nsort_by);
	use Env qw(CTHIST_DOWNLOAD_TEST_DIR_PREFIX);

	use Moo;

	has nctid => ( is => 'ro', isa => NCT_ID, required => 1 );

	use constant DOWNLOAD_PATH => do {
		path(
			( exists $ENV{CTHIST_DOWNLOAD_TEST_DIR_PREFIX}
			? $ENV{CTHIST_DOWNLOAD_TEST_DIR_PREFIX}
			: ()
			),
			'download/ctgov/historical'
		);
	};

=head2 store_path

Uses prefix of NCT ID to partition data so that there is not one large
directory of JSON Lines files.

=cut
	signature_for store_path => ( method => 1, pos => [] );
	sub store_path($self) {
		return DOWNLOAD_PATH->child(substr($self->nctid, 0, 6), "@{[ $self->nctid ]}.jsonl");
	}

	signature_for load => ( method => 1, pos => []);
	sub load :ReturnType(InstanceOf['StudyRecords']) ($self) {
		my $record_file = $self->store_path;
		if( -r $record_file ) {
			return StudyRecords->FROM_JSON_LINES([
				map { $json->decode($_) }
				$record_file->lines_raw( { chomp => 1 } ) ]);
		} else {
			return StudyRecords->new;
		}
	}

	signature_for store => (
		method => 1,
		pos => [ InstanceOf['StudyRecords'] ] );
	sub store($self, $records) {
		main::_log("@{[ $self->nctid ]}: Writing: " . join(' ', $records->study_versions->@* ) );
		my $record_file = $self->store_path;
		$record_file->parent->mkdir;
		$record_file->spew_raw( [
			map { $json->encode($_) . "\n" }
			$records->TO_JSON_LINES->@*
		]);
	}
}

package CTGovAPI {
	use Type::Params 2.000 qw(signature_for);
	use Types::Common qw(Str);
	use CTTypes qw(
		NCT_ID VersionNumber
		CTVersionsData CTStudyRecordData
	);

	my $ua = LWP::UserAgent->new;

	sub _fetch_json_or_die($url) {
		main::_log("Fetching <$url>");
		my $res = $ua->get($url);

		if( ! $res->is_success ) {
			die "Failed to download $url: @{[ $res->message ]}";
		}

		return $json->decode( $res->decoded_content );
	}

	signature_for _get_versions_url => (
		pos => [ NCT_ID ] );
	sub _get_versions_url($nctid) {
		return "https://clinicaltrials.gov/api/int/studies/${nctid}/history";
	}

	signature_for _get_study_record_url => (
		pos => [ NCT_ID, VersionNumber ] );
	sub _get_study_record_url($nctid, $version) {
		return "https://clinicaltrials.gov/api/int/studies/${nctid}/history/${version}";
	}

	signature_for get_versions => (
		method => Str,
		pos => [ NCT_ID ] );
	sub get_versions :ReturnType(CTVersionsData) ($class, $nctid) {
		return _fetch_json_or_die(_get_versions_url($nctid));
	}

	signature_for get_study_record => (
		method => Str,
		pos => [ NCT_ID, VersionNumber ]);
	sub get_study_record :ReturnType(CTStudyRecordData) ($class, $nctid, $version) {
		return _fetch_json_or_die(_get_study_record_url($nctid, $version));
	}
}

use Env qw(CTHIST_DOWNLOAD_CUTOFF_DATE);

sub _has_opt_cutoff_date {
	return exists $ENV{CTHIST_DOWNLOAD_CUTOFF_DATE}
		&& $ENV{CTHIST_DOWNLOAD_CUTOFF_DATE} =~ /\A\d{4}-\d{2}-\d{2}\z/a;
}

signature_for filtered_version_numbers => (
	pos => [ InstanceOf['StudyRecords'] ] );
sub filtered_version_numbers($study_records) {
	if( _has_opt_cutoff_date ) {
		return [
			map { $_->{version} }
			nmax_by { $_->{version} }
			grep {
				# ISO 8601 date → can use string cmp
				$_->{date} le $ENV{CTHIST_DOWNLOAD_CUTOFF_DATE}
			}
			values $study_records->change_map->%*
		];
	}

	return $study_records->change_versions;
}

sub main {
	my $nctid = shift @ARGV;
	my $store = StudyRecords::Store->new( nctid => $nctid);
	my $study_records = $store->load;
	if( $study_records->change_count == 0 ) {
		main::_log("Fetching versions");
		$study_records->add_versions_data( CTGovAPI->get_versions($nctid) );
	}
	main::_log("$nctid: number of versions: @{[ $study_records->change_count ]}");
	my $filtered = filtered_version_numbers($study_records);
	main::_log("$nctid: number of versions after filtering: @{[ scalar @$filtered ]}");
	for my $version (@$filtered) {
		next if defined $study_records->study_map->{$version};

		my $study_record = CTGovAPI->get_study_record($nctid, $version );
		$study_records->add_study_record($study_record);
		$store->store($study_records);
	}
}

main;
