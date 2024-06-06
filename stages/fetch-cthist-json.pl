#!/usr/bin/env perl
# PODNAME: fetch-cthist-json.pl
# ABSTRACT: Retrives or updates historical Clinical Trials data

use strict;
use warnings;
use feature qw(say signatures postderef try);
no warnings qw(experimental::signatures experimental::postderef experimental::try);

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

# Output must but canonical for hashing.
my $json = Cpanel::JSON::XS->new->utf8->canonical;

sub _log { say STDERR @_; }

####

package CTTypes {
	use Exporter::Shiny -setup => {
		exports => [qw(
			NCT_ID
			VersionNumber

			CTVersionsData_Change

			CTVersionsData
			CTStudyRecordDataUnversioned
			CTStudyRecordDataVersioned

			StudyRecord_JSONL_Collection_Versioned
			StudyRecord_JSONL_Collection_Unversioned
			StudyRecord_JSONL_Collection
		)],
	};
	use Types::Common qw(
		StrMatch Dict Slurpy HashRef ArrayRef
		PositiveOrZeroInt Maybe
		Undef
	);

	## Basic types
	use constant {
		NCT_ID        => StrMatch[qr/ \A NCT [0-9]{8} \z /x ],
		VersionNumber => PositiveOrZeroInt
	};

	## From API
	use constant CTVersionsData_Change         => Dict[version => VersionNumber, Slurpy[HashRef] ];
	use constant CTStudyRecordData_Study =>
		HashRef;
		# Keep this generic for now instead of:
		#Dict[
		#	protocolSection => HashRef,
		#	Optional[ derivedSection  => HashRef ],
		#	Optional[ resultsSection  => HashRef ],
		#	hasResults      => Bool,
		#];
	use constant CTStudyRecordDataUnversioned =>
		Dict[ study => CTStudyRecordData_Study ];
	use constant CTStudyRecordDataVersioned =>
		Dict[studyVersion => VersionNumber, study => CTStudyRecordData_Study ];
	use constant CTVersionsData =>
		Dict[changes => ArrayRef[CTVersionsData_Change]];

	## Serialization
	# Individual line of JSON Lines
	use constant StudyRecord_JSONL_Versioned =>
		Dict[ change => CTVersionsData_Change, studyRecord => Maybe[CTStudyRecordDataVersioned] ];
	use constant StudyRecord_JSONL_Unversioned =>
		Dict[ change => Undef, studyRecord => CTStudyRecordDataUnversioned ];
	# Types for collection of JSON Lines
	use constant StudyRecord_JSONL_Collection_Versioned =>
		ArrayRef[StudyRecord_JSONL_Versioned, 1];
	use constant StudyRecord_JSONL_Collection_Unversioned =>
		ArrayRef[StudyRecord_JSONL_Unversioned,1,1];
	use constant StudyRecord_JSONL_Collection =>
		( StudyRecord_JSONL_Collection_Versioned
		| StudyRecord_JSONL_Collection_Unversioned
		);
}

package StudyRecords {
	use Moo;
	use List::Util 1.44 qw(uniqnum);
	use List::UtilsBy qw(nsort_by);
	use Type::Params 2.000 qw(signature_for);
	use Types::Common qw(Str Map InstanceOf Bool PositiveOrZeroInt);
	use Return::Type;
	use CTTypes qw(
		StudyRecord_JSONL_Collection
		StudyRecord_JSONL_Collection_Versioned
		StudyRecord_JSONL_Collection_Unversioned

		VersionNumber

		CTVersionsData_Change
		CTVersionsData

		CTStudyRecordDataUnversioned
		CTStudyRecordDataVersioned
	);

	has history_available => ( is => 'rw', isa => Bool, default => sub { !!0 } );

	# When history_available is false
	has single_study_record => ( is => 'rw',
		predicate => 1,
		trigger => 1,
		isa => CTStudyRecordDataUnversioned );

	sub _trigger_single_study_record($self, $value) {
		$self->history_available(!!0);
	}

	# When history_available is true
	has change_map => ( is => 'rw',
		isa => Map[VersionNumber, CTVersionsData_Change],
		default => sub { +{} }, );
	has study_map  => ( is => 'rw',
		isa => Map[VersionNumber, CTStudyRecordDataVersioned],
		default => sub { +{} }, );

	sub _change_count($self) { 0 + keys $self->change_map->%* }
	sub change_versions($self) { [ sort { $a <=> $b } keys $self->change_map->%* ] }
	sub study_versions($self) { [ sort { $a <=> $b } map { $_->{studyVersion} } values $self->study_map->%* ] }

	signature_for number_of_studies => ( method => 1, pos => []);
	sub number_of_studies :ReturnType(PositiveOrZeroInt) ($self) {
		if( ! $self->history_available && $self->has_single_study_record ) {
			return 1;
		} elsif(  $self->history_available )  {
			return $self->_change_count;
		}

		return 0;
	}

	signature_for add_change => (
		method => 1,
		pos => [ CTVersionsData_Change ]);
	sub add_change($self, $change) {
		$self->history_available(!!1);
		$self->change_map->{ $change->{version} } = $change;
	}

	signature_for add_versions_data => (
		method => 1,
		pos => [ CTVersionsData ]);
	sub add_versions_data($self, $versions) {
		$self->add_change($_) for $versions->{changes}->@*;
	}

	signature_for add_study_record_versioned => (
		method => 1,
		pos => [ CTStudyRecordDataVersioned ]);
	sub add_study_record_versioned($self, $study_record) {
		die "Change data not set" unless $self->history_available;
		$self->study_map->{ $study_record->{studyVersion} } = $study_record;
	}

	signature_for FROM_JSON_LINES => (
		method => Str,
		pos => [ StudyRecord_JSONL_Collection ]);
	sub FROM_JSON_LINES :ReturnType(InstanceOf['StudyRecords']) ($class, $data) {
		if( StudyRecord_JSONL_Collection_Versioned->check($data) ) {
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
				history_available => !!1,
				change_map => \%change_map,
				study_map  => \%study_map,
			);
		} elsif( StudyRecord_JSONL_Collection_Unversioned->check($data) ) {
			return $class->new(
				history_available => !!0,
				single_study_record => $data->[0]{studyRecord},
			)
		}
	}

	signature_for TO_JSON_LINES => ( method => 1, pos => []);
	sub TO_JSON_LINES :ReturnType(StudyRecord_JSONL_Collection) ($self) {
		if( $self->history_available ) {
			my @versions = uniqnum sort { $a <=> $b } (
				keys $self->change_map->%*,
				keys $self->study_map->%*
			);
			# StudyRecord_JSONL_Collection_Versioned
			return [ map { +{
					change      => $self->change_map->{$_},
					studyRecord =>
						# make the undef explicit
						( exists $self->study_map->{$_}
						? $self->study_map->{$_}
						: undef
						),
				} } @versions ];
		} else {
			# StudyRecord_JSONL_Collection_Unversioned
			return [ +{
					change      => undef,
					studyRecord => $self->single_study_record,
				} ];

		}
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
		CTVersionsData
		CTStudyRecordDataVersioned
		CTStudyRecordDataUnversioned
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

	signature_for _get_study_record_version_url => (
		pos => [ NCT_ID, VersionNumber ] );
	sub _get_study_record_version_url($nctid, $version) {
		return "https://clinicaltrials.gov/api/int/studies/${nctid}/history/${version}";
	}

	signature_for _get_study_record_latest_url => (
		pos => [ NCT_ID ] );
	sub _get_study_record_latest_url($nctid) {
		return "https://clinicaltrials.gov/api/int/studies/${nctid}";
	}

	signature_for get_versions => (
		method => Str,
		pos => [ NCT_ID ] );
	sub get_versions :ReturnType(CTVersionsData) ($class, $nctid) {
		return _fetch_json_or_die(_get_versions_url($nctid));
	}

	signature_for get_study_record_version => (
		method => Str,
		pos => [ NCT_ID, VersionNumber ]);
	sub get_study_record_version :ReturnType(CTStudyRecordDataVersioned) ($class, $nctid, $version) {
		return _fetch_json_or_die(_get_study_record_version_url($nctid, $version));
	}

	signature_for get_study_record_latest => (
		method => Str,
		pos => [ NCT_ID ]);
	sub get_study_record_latest :ReturnType(CTStudyRecordDataUnversioned) ($class, $nctid) {
		return _fetch_json_or_die(_get_study_record_latest_url($nctid));
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
	if( $study_records->number_of_studies == 0 ) {
		main::_log("Fetching versions");
		my $versions_data = do {
			try {
				CTGovAPI->get_versions($nctid);
			} catch( $e ) {
				chomp $e;
				main::_log("No version history for NCT ID $nctid: $e");
				undef;
			}
		};
		if( defined $versions_data ) {
			$study_records->add_versions_data($versions_data);
		} else {
		}
	}
	if( $study_records->history_available ) {
		main::_log("$nctid: using historical data");
		main::_log("$nctid: number of versions: @{[ $study_records->number_of_studies ]}");
		my $filtered = filtered_version_numbers($study_records);
		main::_log("$nctid: number of versions after filtering: @{[ scalar @$filtered ]}");
		for my $version (@$filtered) {
			next if defined $study_records->study_map->{$version};

			my $study_record = CTGovAPI->get_study_record_version($nctid, $version );
			$study_records->add_study_record_versioned($study_record);
			$store->store($study_records);
		}
	} else {
		main::_log("$nctid: using latest data");
		if( ! $study_records->has_single_study_record ) {
			my $latest_study = CTGovAPI->get_study_record_latest($nctid);
			$study_records->single_study_record($latest_study);
			$store->store($study_records);
		}
	}
}

main;
