#!/usr/bin/env perl

use utf8;
use strict;
use warnings;

use Test::More tests => 2;

use Path::Tiny qw(path);
use Capture::Tiny qw(capture_stdout capture_stderr tee_stderr);
use Encode qw(decode_utf8);

my $tmp_dir = Path::Tiny->tempdir;
$ENV{CTHIST_DOWNLOAD_TEST_DIR_PREFIX} = "$tmp_dir";
delete $ENV{CTHIST_DOWNLOAD_CUTOFF_DATE};

sub _run_fetch {
	my ($nctid) = @_;
	my ($stderr, $exit) = capture_stderr {
		system( './stages/fetch-cthist-json.pl', $nctid )
	};
	$exit == 0 or die $stderr;
	diag $stderr =~ s/^/|> /gmr;
	return $stderr;
}

sub _run_duckdb {
	my ($sql) = @_;
	my $output = capture_stdout {
		0 == system('duckdb', qw(-noheader -csv -c), $sql) or die;
	};
	chomp $output;
	return Encode::decode_utf8($output);
}

sub _count_study_records {
	my ($file) = @_;

	my $duckdb_count = 0 + _run_duckdb(<<~SQL);
		SELECT
			COUNT(DISTINCT studyRecord.studyVersion)
				AS answer
		FROM read_ndjson_auto('$file');
	SQL

	return $duckdb_count;
}

sub _do_versions_match {
	my ($file) = @_;
	return 'true' eq _run_duckdb(<<~SQL)
		SELECT ALL(
			SELECT
				studyRecord.studyVersion == change.version
			FROM read_ndjson_auto('$file')
		) AS answer;
	SQL
}

sub _did_fetch_versions {
	my ($output) = @_;
	like $output, qr/\QFetching versions\E$/m, 'did fetch versions';
}
sub _did_not_fetch_versions {
	my ($output) = @_;
	unlike $output, qr/\QFetching versions\E$/m, 'did not fetch versions';
}

subtest "NCT04243421" => sub {
	my $nctid = 'NCT04243421';
	my $file = $tmp_dir->child('download/ctgov/historical/NCT042/NCT04243421.jsonl');
	note "Output will be in file: $file";

	my $output = _run_fetch($nctid);
	_did_fetch_versions($output);
	like $output,
		qr/\Qnumber of versions after filtering: 5\E$/m,
		'expected output';

	ok -r $file, 'has file output';

	is _count_study_records($file), 5, '5 study records';

	ok _do_versions_match($file), 'studyVersion.studyVersion matches change.version';

	like _run_duckdb(<<~SQL),
		SELECT
			DISTINCT
				studyRecord
				.study.protocolSection
				.contactsLocationsModule.locations[1].city
			AS answer
		FROM read_ndjson_auto('$file');
	SQL
		, qr/\A"Białystok"\z/s,
		'location contains expected Unicode';
};

subtest "NCT00000125" => sub {
	my $nctid = 'NCT00000125';
	my $file = $tmp_dir->child('download/ctgov/historical/NCT000/NCT00000125.jsonl');
	note "Output will be in file: $file";

	subtest "NCT00000125 as usual (no cut-off)" => sub {
		my $output = _run_fetch($nctid);
		_did_fetch_versions($output);
		like $output,
			qr/\Qnumber of versions after filtering: 16\E$/m,
			'expected output';

		ok -r $file, 'has file output';

		is _count_study_records($file), 16, '16 study records';

		ok _do_versions_match($file),
			'studyVersion.studyVersion matches change.version';
	};

	my $CUTOFF_DATE = '2013-09-27';
	my $CUTOFF_DATE_VERSION_URL = 'https://clinicaltrials.gov/api/int/studies/NCT00000125/history/5';
	my $_did_not_download_cutoff_version = sub {
		unlike shift,
			qr/\Q<$CUTOFF_DATE_VERSION_URL>\E/m,
			'did not download cut-off version';
	};
	my $_did_download_cutoff_version = sub {
		like shift,
			qr/\Q<$CUTOFF_DATE_VERSION_URL>\E/m,
			'did download cut-off version';
	};
	subtest "NCT00000125 again but with cut-off" => sub {
		local $ENV{CTHIST_DOWNLOAD_CUTOFF_DATE} = $CUTOFF_DATE;

		ok -r $file, 'has file output already';

		my $output = _run_fetch($nctid);
		_did_not_fetch_versions($output);
		like $output,
			qr/\Qnumber of versions after filtering: 1\E$/m,
			'expected output';

		$_did_not_download_cutoff_version->( $output );

		ok -r $file, 'has file output';

		is _count_study_records($file), 16,
			'still 16 study records (existing not removed)';

		note "but now remove the file $file";
		path($file)->remove;

		$output = _run_fetch($nctid);
		_did_fetch_versions($output);

		$_did_download_cutoff_version->($output);

		ok -r $file, 'has file output';

		is _count_study_records($file), 1,
			'only 1 study records fetch when given cut-off';
	};

	subtest "NCT00000125 again, no cut-off, grab rest of data" => sub {
		ok -r $file, 'has file output already';

		my $output = _run_fetch($nctid);
		_did_not_fetch_versions($output);
		like $output,
			qr/\Qnumber of versions after filtering: 16\E$/m,
			'expected output';

		$_did_not_download_cutoff_version->( $output );

		ok -r $file, 'has file output';

		is _count_study_records($file), 16,
			'now has 16 study records (rest have been added)';

		ok _do_versions_match($file),
			'studyVersion.studyVersion matches change.version';

		my $change_versions =  _run_duckdb(<<~SQL);
			SELECT change.version
			FROM read_ndjson_auto('$file');
		SQL
		my @change_versions =  split(/\n/, $change_versions);

		diag explain \@change_versions;
		is_deeply \@change_versions, [0..15],
		'change versions are in the correct order';
	};
};


done_testing;
