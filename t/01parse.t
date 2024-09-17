#!perl

use v5.36;
use Test::More;
use Try::Tiny;
use DateTime;
use DateTimeX::Quickie;

sub s_to_ns ($s) {
	$s * 1_000_000_000
}

sub h_to_sec ($h) {
	$h * 3600;
}

my ($dt, $dt0, $dt1);

#################
# Epoch Parsing #

# epoch and negative epoch
ok($dt0 = DateTime->quickie(    scalar time), 'quickie with positive epoch');
ok($dt1 = DateTime->quickie(0 - scalar time), 'quickie with negative epoch');
ok($dt0->year > 1970,                        'positive epoch is after 1970');
ok($dt1->year < 1970,                        'negative epoch is before 1970');

# Test known samples to match expected values
is(DateTime->quickie( 123456789)    => '1973-11-29T21:33:09', 'known +epoch gives correct date');
is(DateTime->quickie(-123456789)    => '1966-02-02T02:26:51', 'known -epoch gives correct date');
is(DateTime->quickie( 123456789.5)  => '1973-11-29T21:33:09', 'known +epoch with fractional seconds gives correct date with rounding');
is(DateTime->quickie(-123456789.5)  => '1966-02-02T02:26:50', 'known +epoch with fractional seconds gives correct date with rounding');

# Test fractional seconds
is(DateTime->quickie( 123456789.5  )->nanosecond => s_to_ns(  0.5 ),  '+epoch with nanoseconds (1 decimal place) correct');
is(DateTime->quickie( 123456789.333)->nanosecond => s_to_ns(  0.333), '+epoch with nanoseconds (3 decimal places) correct');
is(DateTime->quickie(-123456789.667)->nanosecond => s_to_ns(1-0.667), '-epoch with nanoseconds correct');

################
# List Parsing #

# quickie via a list, without time zone
ok($dt = DateTime->quickie(2020, 2, 28, 12, 30, 15), 'quickie via list');
ok(
	(
		$dt->year   == 2020 and
		$dt->month  ==    2 and
		$dt->day    ==   28 and
		$dt->hour   ==   12 and
		$dt->minute ==   30 and
		$dt->second ==   15
	),
	'new object has correct values'
);
ok(
	ref $dt->time_zone eq 'DateTime::TimeZone::Floating',
	'new object has floating timezone'
);

# list, only specifying year
ok($dt = DateTime->quickie(2020, undef, undef),      'quickie with list, but only specify the year');
ok($dt eq "2020-01-01T00:00:00",                    '...new object is correct');
ok($dt->time_zone->name eq 'floating',              '...new object has floating timezone');

# list with time zone at beginning
ok($dt = DateTime->quickie('America/Chicago', 2020), 'quickie with time zone in beginning');
ok($dt eq "2020-01-01T00:00:00",                    '...new object is correct');
ok($dt->time_zone->name eq 'America/Chicago',       '...new object has correct timezone');

# list with time zone at end
ok($dt = DateTime->quickie(2020, 'EST'),             'quickie with time zone at end');
ok($dt eq "2020-01-01T00:00:00",                    '...new object is correct');
ok($dt->time_zone->name eq 'EST',                   '...new object has correct timezone');

# list with all elements undef
ok($dt = DateTime->quickie(undef, undef),            'quickie with list, but with only undef elements');
ok($dt eq "0000-01-01T00:00:00",                    '...new object is correct');

# arrayref
ok($dt = DateTime->quickie([]),                      'quickie with arrayref, but empty');
ok($dt eq "0000-01-01T00:00:00",                    '...new object is correct');
ok($dt = DateTime->quickie([2020]),                  'quickie with arrayref, but only the year');
ok($dt eq "2020-01-01T00:00:00",                    '...new object is correct');
ok($dt = DateTime->quickie([2020, 07, 04]),          'quickie with arrayref, with y,m,d');
ok($dt eq "2020-07-04T00:00:00",                    '...new object is correct');

#################
# Empty parsing #
ok($dt = DateTime->quickie,                          'quickie with nothing');
ok($dt eq "0000-01-01T00:00:00",                    '...new object is correct');

##################
# String Parsing #

# string, simple
ok($dt = DateTime->quickie('1980-10-10 01:02:03'),     'quickie datetime from iso string (plain)');
ok($dt eq '1980-10-10T01:02:03',                      'new object is correct');

# string, fractional seconds
ok($dt = DateTime->quickie('1990-11-11 02:03:04.5'),   'quickie datetime with fractional seconds');
ok($dt->nanosecond == 500_000_000,                    'nanosecond is correct');

ok($dt = DateTime->quickie('1990-11-11 02:03:04.234'), 'quickie datetime with hires seconds');
ok($dt->nanosecond == 234_000_000,                    'nanosecond is correct');


# string with +02 offset
ok($dt = DateTime->quickie('1989-06-05T12:02:59.56+02'),    'quickie datetime with timezone offset (+02)');
is($dt => '1989-06-05T12:02:59',                           'datetime is converted to UTC using offset');
is($dt->offset => h_to_sec(2),                             'offset is correct');

# string with -03 offset
ok($dt = DateTime->quickie('1989-06-05T12:02:59.56-03'),    'quickie datetime with timezone offset (-03)');
is($dt => '1989-06-05T12:02:59',                           'datetime is converted to UTC using offset');
is($dt->offset => h_to_sec(-3),                            'offset is correct');

# string with +01:30 offset
ok($dt = DateTime->quickie('1989-06-05T12:02:59.56+01:30'), 'quickie datetime with timezone offset (+01:30)');
is($dt => '1989-06-05T12:02:59',                           'datetime is converted to UTC using offset');
is($dt->offset => h_to_sec(1.5),                           'offset is correct');

# string with -02:30 offset
ok($dt = DateTime->quickie('1989-06-05T12:02:59.56-02:30'), 'quickie datetime with timezone offset (-02:30)');
is($dt => '1989-06-05T12:02:59',                           'datetime is converted to UTC using offset');
is($dt->offset => h_to_sec(-2.5),                          'offset is correct');

# string with +0130 offset
ok($dt = DateTime->quickie('1989-06-05T12:02:59.56+0130'),  'quickie datetime with timezone offset (+0130)');
is($dt => '1989-06-05T12:02:59',                           'datetime is converted to UTC using offset');
is($dt->offset => h_to_sec(1.5),                           'offset is correct');

# string with offset, force internal parser
$DateTimeX::Quickie::force_parser = 'internal';
ok($dt = DateTime->quickie('1989-06-05T12:02:59.56+02'),    'force internal quickie with offset +02');
ok($dt = DateTime->quickie('1989-06-05T12:02:59.56-05'),    'force internal quickie with offset -05');
ok($dt = DateTime->quickie('1989-06-05T12:02:59.56+02:30'), 'force internal quickie with offset +02:30');
ok($dt = DateTime->quickie('1989-06-05T12:02:59.56-05:30'), 'force internal quickie with offset -05:30');
undef $DateTimeX::Quickie::force_parser;

# string with offset, force external parser
# Note DateTime::Format::ISO8601 sometimmes requires the separator in the offset
$DateTimeX::Quickie::force_parser = 'external';
ok($dt = DateTime->quickie('1989-06-05T12:02:59.56+02'), 'force external quickie with + offset');
ok($dt = DateTime->quickie('1989-06-05T12:02:59.1-07:00'), 'force external quickie with - offset ');
undef $DateTimeX::Quickie::force_parser;

# this string is only handled by DateTime::Format::ISO8601 module
ok($dt = DateTime->quickie('20230302T060226Z'),             'quickie datetime from ISO string that can only be parsed externally');
is($dt => '2023-03-02T06:02:26',                           'datetime is correct');

# string with both offset and zulu should be invalid
try {
	local $SIG{__WARN__} = sub { };
	undef $dt;
	$dt = DateTime->quickie('1989-06-05T12:02:59.56Z-02:30');
};
is($dt => undef, 'Z and offset are invalid when used together');


########
# Done #

done_testing();

