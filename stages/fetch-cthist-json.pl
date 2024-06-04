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
use Return::Type;

my $json = Cpanel::JSON::XS->new->utf8;

sub _log { say STDERR @_; }

####

package CTTypes {
       use Exporter::Shiny -setup => {
          exports => [qw(
			NCT_ID
			VersionNumber

			CTVersionsData
			CTStudyRecordData

			StudyRecordCollection
		)],
       };
	use Types::Common qw(StrMatch Dict Slurpy HashRef ArrayRef PositiveOrZeroInt);

	## Basic types
	use constant {
		NCT_ID        => StrMatch[qr/ \A NCT [0-9]{8} \z /x ],
		VersionNumber => PositiveOrZeroInt
	};

	## From API
	use constant _CTVersionChange         => Dict[version => VersionNumber, Slurpy[HashRef] ];
	use constant {
		CTStudyRecordData => Dict[studyVersion => VersionNumber, study => HashRef],
		CTVersionsData    => Dict[changes => ArrayRef[_CTVersionChange]],
	};

	## Serialization
	use constant _StudyRecord => Dict[ change => _CTVersionChange, studyRecord => CTStudyRecordData ];
	use constant StudyRecordCollection => ArrayRef[_StudyRecord];
}

package StudyRecord {
	use Type::Params 2.000 qw(signature_for);
	use Types::Common qw(Str);
	use CTTypes qw(NCT_ID StudyRecordCollection);
	use Path::Tiny 0.144 qw(path);
	use List::UtilsBy qw(nsort_by);

	use constant DOWNLOAD_PATH => do {
		path(
			( exists $ENV{CTHIST_DOWNLOAD_TEST_DIR_PREFIX}
			? $ENV{CTHIST_DOWNLOAD_TEST_DIR_PREFIX}
			: ()
			),
			'download/ctgov/historical'
		);
	};

=head2 path_for_nctid

Uses prefix of NCT ID to partition data so that there is not one large
directory of JSON Lines files.

=cut
	signature_for path_for_nctid => (
		pos => [ NCT_ID ] );
	sub path_for_nctid($nctid) {
		return DOWNLOAD_PATH->child(substr($nctid, 0, 6), "${nctid}.jsonl");
	}

	signature_for load_study_records => (
		pos => [ NCT_ID ]);
	sub load_study_records :ReturnType(StudyRecordCollection) ($nctid) {
		my $record_file = path_for_nctid($nctid);
		if( -r $record_file ) {
			return [
				map { $json->decode($_) }
				$record_file->lines_raw( { chomp => 1 } ) ];
		} else {
			return [];
		}
	}

	signature_for store_study_records => (
		pos => [ NCT_ID, StudyRecordCollection ] );
	sub store_study_records($nctid, $records) {
		main::_log("$nctid: Writing: " . join(' ', map { $_->{change}{version} } @$records) );
		my $record_file = path_for_nctid($nctid);
		$record_file->parent->mkdir;
		$record_file->spew_raw( [
			map { $json->encode($_) . "\n" }
			nsort_by { $_->{change}{version} }
			@$records
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

use CTTypes qw( CTVersionsData );

sub _has_opt_cutoff_date {
	return exists $ENV{CTHIST_DOWNLOAD_CUTOFF_DATE}
		&& $ENV{CTHIST_DOWNLOAD_CUTOFF_DATE} =~ /\A\d{4}-\d{2}-\d{2}\z/a;
}

signature_for opt_filter_study_records => (
	pos => [ CTVersionsData ] );
sub opt_filter_study_records($versions_data) {
	# CTVersionsData $versions_data
	# NOTE modifies $versions_data
	if( _has_opt_cutoff_date ) {
		$versions_data->{changes}->@* =
			nmax_by { $_->{version} }
			grep {
				# ISO 8601 date → can use string cmp
				$_->{date} le $ENV{CTHIST_DOWNLOAD_CUTOFF_DATE}
			}
			$versions_data->{changes}->@*;
	}
}

sub main {
	my $nctid = shift @ARGV;
	my $study_records = StudyRecord::load_study_records($nctid);
	my $versions_data =
		_has_opt_cutoff_date() && @$study_records > 0
		? { changes => [ map { $_->{change} } @$study_records ] }
		: CTGovAPI->get_versions($nctid);
	main::_log("$nctid: number of versions: @{[ 0+$versions_data->{changes}->@* ]}");
	opt_filter_study_records($versions_data);
	main::_log("$nctid: number of versions after filtering: @{[ 0+$versions_data->{changes}->@* ]}");
	for my $change ($versions_data->{changes}->@*) {
		next if any {
				$change->{version} == $_->{change}{version}
			} @$study_records;

		my $study_record = CTGovAPI->get_study_record($nctid, $change->{version} );

		push @$study_records, {
			change      => $change,
			studyRecord => $study_record,
		};

		StudyRecord::store_study_records($nctid, $study_records);
	}
}

main;
