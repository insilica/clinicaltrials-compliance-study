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
	my ($stdout) = capture_stderr {
		0 == system( './stages/fetch-cthist-json.pl', $nctid ) or die;
	};
	diag $stdout =~ s/^/|> /gmr;
	return $stdout;
}

sub _run_duckdb {
	my ($sql) = @_;
	my $output = capture_stdout {
		0 == system('duckdb', qw(-noheader -csv -c), $sql) or die;
	};
	chomp $output;
	return $output;
}

sub _count_study_records {
	my ($file) = @_;

	my $duckdb_count = 0 + _run_duckdb(<<~SQL);
		SELECT
			COUNT(DISTINCT studyRecord.studyVersion)
				AS answer
		FROM read_ndjson('$file');
	SQL

	my $line_count = path($file)->lines_raw;

	die "Mismatch between DuckDB and file!"
		unless $duckdb_count == $line_count;

	return $duckdb_count;
}

sub _do_versions_match {
	my ($file) = @_;
	return 'true' eq _run_duckdb(<<~SQL)
		SELECT ALL(
			SELECT
				studyRecord.studyVersion == change.version
			FROM read_ndjson('$file')
		) AS answer;
	SQL
}

subtest "NCT04243421" => sub {
	my $nctid = 'NCT04243421';
	my $file = $tmp_dir->child('download/ctgov/historical/NCT042/NCT04243421.jsonl');
	note "Output will be in file: $file";

	like _run_fetch($nctid),
		qr/\Qnumber of versions after filtering: 5\E$/m,
		'expected output';

	ok -r $file, 'has file output';

	is _count_study_records($file), 5, '5 study records';

	ok _do_versions_match($file), 'studyVersion.studyVersion matches change.version';

	like Encode::decode_utf8( _run_duckdb(<<~SQL) ),
		SELECT
			DISTINCT
				studyRecord
				.study.protocolSection
				.contactsLocationsModule.locations[1].city
			AS answer
		FROM read_ndjson('$file');
	SQL
		, qr/\A"Białystok"\z/s,
		'location contains expected Unicode';
};

subtest "NCT00000125" => sub {
	my $nctid = 'NCT00000125';
	my $file = $tmp_dir->child('download/ctgov/historical/NCT000/NCT00000125.jsonl');
	note "Output will be in file: $file";

	subtest "NCT00000125 as usual (no cut-off)" => sub {
		like _run_fetch($nctid),
			qr/\Qnumber of versions after filtering: 16\E$/m,
			'expected output';

		ok -r $file, 'has file output';

		is _count_study_records($file), 16, '16 study records';

		ok _do_versions_match($file),
			'studyVersion.studyVersion matches change.version';
	};

	subtest "NCT00000125 again but with cut-off" => sub {
		local $ENV{CTHIST_DOWNLOAD_CUTOFF_DATE} = '2013-09-27';

		ok -r $file, 'has file output already';

		like _run_fetch($nctid),
			qr/\Qnumber of versions after filtering: 1\E$/m,
			'expected output';

		ok -r $file, 'has file output';

		is _count_study_records($file), 16,
			'still 16 study records (existing not removed)';

		note "but now remove the file $file";
		path($file)->remove;

		_run_fetch($nctid);

		ok -r $file, 'has file output';

		is _count_study_records($file), 1,
			'only 1 study records fetch when given cut-off';
	};

	subtest "NCT00000125 again, no cut-off, grab rest of data" => sub {
		ok -r $file, 'has file output already';

		like _run_fetch($nctid),
			qr/\Qnumber of versions after filtering: 16\E$/m,
			'expected output';

		ok -r $file, 'has file output';

		is _count_study_records($file), 16,
			'now has 16 study records (rest have been added)';

		ok _do_versions_match($file),
			'studyVersion.studyVersion matches change.version';

		my $change_versions =  _run_duckdb(<<~SQL);
			SELECT change.version
			FROM read_ndjson('$file');
		SQL
		my @change_versions =  split(/\n/, $change_versions);

		diag explain \@change_versions;
		is_deeply \@change_versions, [0..15],
		'change versions are in the correct order';
	};
};


done_testing;
