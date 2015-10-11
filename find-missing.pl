#!/usr/bin/perl -w

use strict;
use warnings;

use Digest::SHA qw ( sha512 );

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

sub processFile {
	my ($filename, $processEmail) = @_;

	open( my $fh => $filename ) || die "Cannot open $filename: $!";

	my $fromLine = '';
	my $headers = '';
	my $body = '';

	my $isReadingHeaders = 0;
	my $sawBlankLine = 1;
	while (my $line = <$fh>) {
		if ($line =~ /^From\s/ && $sawBlankLine) {
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
