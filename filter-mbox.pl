#!/usr/bin/perl -w

use strict;
use warnings;

use MIME::Parser;
use Date::Manip;

my $startDate = parseDate(shift @ARGV);
my $endDate = parseDate(shift @ARGV);

my $Context = "";

sub parseDate {
	my ($date) = @_;

	my $originalDate = $date;

	$date =~ s/[^\d]+$//;
	$date =~ s/\s*\(\w+\)$//;

	my $parsedDate = ParseDate($date);
	die "$Context: Failed to parse date: '$originalDate'" unless length $parsedDate;

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

	my $parser = new MIME::Parser;
	$parser->output_to_core(1);
	my $entity = $parser->parse_data($headers) or die "Failed to parse headers:\n$headers";
	return $entity->head;
}

sub processEmail {
	my ($fromLine, $headers, $body, $filename) = @_;

	my $didEmailMatch = 0;

	my $head = &getMimeHead($headers);
	if ($head->count('Date')) {
		my $date = $head->get('Date');
		my $parsedDate = parseDate($date);

		$didEmailMatch = isDateInRange($startDate, $parsedDate, $endDate);
	} else {
		my $date = $fromLine;

		$date =~ s/^From\s[^\s]+//;

		my $parsedDate = parseDate($date);
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

		print $body;
	}
}

sub processFile {
	my ($filename) = @_;

	open( my $fh => $filename ) || die "Cannot open $filename: $!";

	my $fromLine = '';
	my $headers = '';
	my $body = '';

	my $isReadingHeaders = 0;
	my $sawBlankLine = 1;
	while (my $line = <$fh>) {
		$Context = "$filename:$.";

		if ($line =~ /^From\s/ && $sawBlankLine) {
		 	&processEmail($fromLine, $headers, $body, $filename) unless !$fromLine;

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

	&processEmail($fromLine, $headers, $body, $filename) unless !$fromLine;
}

foreach my $argument (@ARGV) {
	processFile($argument);
	# print "$startDate to $endDate: $argument\n";
}
