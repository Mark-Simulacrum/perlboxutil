#!/usr/bin/perl -w

use strict;
use warnings;

use Digest::SHA qw ( sha512 );
use Date::Manip;

my $Context = "";
my %emailHashes = ();

sub isBlankLine {
	my ($line) = @_;

	return $line =~ /^\r?\n$/;
}

sub processEmail {
	my ($fromLine, $headers, $body, $filename) = @_;

	if (!exists $emailHashes{sha512($body)}) {
		print $fromLine;
		print $headers;

		if ($headers !~ /^X-Was-Archived-At:/ && $filename ne "-") {
			print "X-Was-Archived-At: $filename\n";
		}

		# The blank line after the headers isn't included for easy addition
		# of more headers.
		print "\n";

		print $body;
	}
}

sub hashEmail {
	my ($fromLine, $headers, $body, $filename) = @_;

	$emailHashes{sha512($body)} = undef;
}

sub parseDate {
	my ($date, $shouldDie) = @_;

	my $originalDate = $date;

	$date =~ s/[^\d]+$//;
	$date =~ s/\s*\(\w+\)$//;
	$date =~ s/\s*\+\d+$//;

	my $parsedDate = ParseDate($date);
	if (!length $parsedDate) {
		die "$Context: Failed to parse date: '$originalDate'" if $shouldDie;
		return undef;
	}

	return $parsedDate;
}

sub getDateOfFromLine {
	my ($fromLine, $isExistenceCheck) = @_;

	my $fromLineOriginal = $fromLine;

	$fromLine =~ s/^From\s[^\s]+//;

	my $parsedDate = parseDate($fromLine, !$isExistenceCheck);
	warn "$Context: Ignoring dateless From line: $fromLineOriginal" unless length $parsedDate;

	return $parsedDate;
}

sub processFile {
	my ($filename, $processEmail) = @_;

	open( my $fh => $filename ) || die "Cannot open $filename: $!";

	my $fromLine = '';
	my $headers = '';
	my $body = '';

	my $isReadingHeaders = 0;
	my $sawBlankLine = 1;
	while (my $line = <$fh>) {
		$Context = "$filename:$.";

		if ($sawBlankLine && $line =~ /^From[^\S\n]/ && getDateOfFromLine($line, 1)) {
			$body = chomp $body;

		 	&{$processEmail}($fromLine, $headers, $body, $filename) unless !$fromLine;

		 	$fromLine = $line;
		 	$headers = '';
		 	$body = '';

		 	$isReadingHeaders = 1;
		} elsif ($isReadingHeaders) {
			if (isBlankLine $line) {
				$isReadingHeaders = 0;
			} else {
				$headers .= $line;
			}
		} else {
			$body .= $line;
		}

		$sawBlankLine = isBlankLine $line;
	}

	$body = chomp $body;

	&{$processEmail}($fromLine, $headers, $body, $filename) unless !$fromLine;
}

my @toBeHashed = ();
my @toBeChecked = ();

my $hasSeenSplitter = 0;
foreach my $argument (@ARGV) {
	if ($argument eq '--in') {
		$hasSeenSplitter = 1;
	} else {
		if ($hasSeenSplitter) {
			push @toBeHashed, $argument;
		} else {
			push @toBeChecked, $argument;
		}
	}
}

foreach my $filename (@toBeHashed) {
	&processFile($filename, \&hashEmail);
}

foreach my $filename (@toBeChecked) {
	&processFile($filename, \&processEmail);
}
