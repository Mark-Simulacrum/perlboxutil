#!/usr/bin/perl -w

use strict;
use warnings;

use MIME::Parser;
use Date::Manip;

my $startDate = parseDate(shift @ARGV, 1);

# End date resolves to a noninclusive format; so we need to add almost
# another day to include all of the emails received on the end date.
my $endDate = DateCalc(parseDate(shift @ARGV, 1), "+ 23 hours 59 minutes 59 seconds");

my $Context = "";

sub parseDate {
	my ($date, $shouldDie) = @_;

	my $originalDate = $date;

	$date =~ s/[^\d]+$//;
	$date =~ s/\s*\(.*?\)$//;
	$date =~ s/\s*[+-]\d+$//;

	my $parsedDate = ParseDate($date);
	if (!length $parsedDate) {
		die "$Context: Failed to parse date: '$originalDate'" if $shouldDie;
		return undef;
	}

	return $parsedDate;
}

sub isDateInRange {
	my ($startDate, $middleDate, $endDate) = @_;

	return 0 unless $startDate && $middleDate && $endDate;

	return Date_Cmp($startDate, $middleDate) <= 0 && Date_Cmp($endDate, $middleDate) >= 0;
}

sub isBlankLine {
	my ($line) = @_;

	return $line =~ /^\r?\n$/;
}

sub getMimeHead {
	my ($headers) = @_;

	$headers =~ s/^Content-Type:/X-Content-Type:/mi;
	$headers =~ s/^Content-Transfer-Encoding:/X-Content-Transfer-Encoding:/mi;

	my $parser = new MIME::Parser;
	$parser->output_to_core(1);
	my $entity = $parser->parse_data($headers) or die "Failed to parse headers:\n$headers";
	return $entity->head;
}

sub getDateOfFromLine {
	my ($fromLine, $isExistenceCheck) = @_;

	my $fromLineOriginal = $fromLine;

	$fromLine =~ s/^From\s[^\s]+//;

	my $parsedDate = parseDate($fromLine, !$isExistenceCheck);
	warn "$Context: Ignoring dateless From line: $fromLineOriginal" unless length $parsedDate;

	return $parsedDate;
}

sub processEmail {
	my ($fromLine, $headers, $filename) = @_;

	my $didEmailMatch = 0;

	my $head = &getMimeHead($headers);
	my $parsedDate;
	if ($head->count('Date')) {
		my $date = $head->get('Date');
		$parsedDate = parseDate($date, 0);

		$didEmailMatch = isDateInRange($startDate, $parsedDate, $endDate);
	}

	if (!defined $parsedDate) {
		my $parsedDate = getDateOfFromLine($fromLine, 0);
		$didEmailMatch = isDateInRange($startDate, $parsedDate, $endDate);
	}

	if ($didEmailMatch) {
		print $fromLine;
		print $headers;

		if ($headers !~ /^X-Was-Archived-At:/ && $filename ne "-") {
			print "X-Was-Archived-At: $filename\n";
		}

		# The blank line after the headers isn't included for easy addition
		# of more headers.
		print "\n";
	}

	return $didEmailMatch;
}

sub processFile {
	my ($filename) = @_;

	open( my $fh => $filename ) || die "Cannot open $filename: $!";

	my $fromLine = '';
	my $headers = '';

	my $isReadingHeaders = 0;
	my $sawBlankLine = 1;
	my $didEmailMatch = 0;
	while (my $line = <$fh>) {
		$Context = "$filename:$.";

		if ($sawBlankLine && $line =~ /^From[^\S\n]/ && getDateOfFromLine($line, 1)) {
		 	$fromLine = $line;
		 	$headers = '';

		 	$isReadingHeaders = 1;
		} elsif ($isReadingHeaders) {
			if (isBlankLine $line) {
				$isReadingHeaders = 0;

				$didEmailMatch = &processEmail($fromLine, $headers, $filename) unless !$fromLine;
			} else {
				$headers .= $line;
			}
		} elsif ($didEmailMatch) {
			print $line;
		}

		$sawBlankLine = isBlankLine $line;
	}
}

foreach my $argument (@ARGV) {
	processFile($argument);
}
