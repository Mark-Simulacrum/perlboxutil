# Filtering and comparison of mboxes in Perl

Depends on MIME::Parser and Date::Manip Perl modules.

## Usage:
`filter-mbox.pl`:
`filter-mbox.pl YYYY-MM-DD YYYY-MM-DD <mbox|->...`

The date range is inclusive, and goes from the first date to the second date.

`find-missing.pl`:
`find-missing.pl <mbox|->... --in <mbox|->...`

First mbox list is a list of parts, and the second mbox list is a list of wholes.
Result is the emails that are missing from the parts that are in the wholes.
