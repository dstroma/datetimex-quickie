#!perl

use v5.36;
use DateTime::Format::DateParse;
use DateTime::Format::ISO8601;
#use DateTimeX::Easy;
use DateTimeX::Create;
use Benchmark 'cmpthese';
use constant ITERATIONS => 2_500;



via_list();
say '';
via_epoch();
say '';
iso_parse();

sub via_list {
	say 'RAW (DateTime->(key => val, ...)) vs. DTC DateTime->create(list)';
	my @bench = (ITERATIONS * 10, {
		'raw' => sub { my $dt = DateTime->new(year => 2020, month => 7, day => 4, hour => 20, minute => 21, second => 15); $dt },
		'dtc' => sub { my $dt = DateTime->create(2020, 7, 4, 20, 21, 15); $dt },
	});

	test_bench(\@bench);
	cmpthese(@bench);
}

sub via_epoch {
	say 'RAW from_epoch vs. DTC create(epoch)';
	my @bench = (ITERATIONS * 10, {
		'raw' => sub { my $dt = DateTime->from_epoch(123456789.87654321); $dt },
		'dtc' => sub { my $dt = DateTime->create(123456789.87654321); $dt },
	});

	test_bench(\@bench);
	cmpthese(@bench);
}

sub iso_parse {
	say "ISO parsing benchmark";

	my @strings = qw(
		2000-01-01T00:00:00
		2345-12-12T12:34:56Z
		1957-12-31T05:06:07+02:30
		1957-12-31T05:06:07-02
		2020-02-03T22:22:22.4321
		2020-02-03T22:22:22.56789+04
		1999-12-31T23:59:59.99999999+00
		1999-12-31T23:59:59.111222333
		20230302T060226Z
	);

	my $dt;

	my @bench = (ITERATIONS, {
	  'dt::f::dp' => sub { $dt = DateTime::Format::DateParse->parse_datetime($_) for @strings; },
	  '::iso8601' => sub { $dt = DateTime::Format::ISO8601->parse_datetime($_)   for @strings; },
	  'x::create' => sub { $dt = DateTime->create($_)  for @strings; },
	  'x::create internal parser' => sub { $dt = DateTimeX::Create::new_from_iso_string_internal('DateTime', $_) for @strings; },
	  'x::create external parser' => sub { $dt = DateTimeX::Create::new_from_iso_string_external('DateTime', $_) for @strings; },
	  }
	);

	#foreach my $href ($bench1[1]) {
	#	foreach my $key (keys %$href) {
	#		my $value = $href->{$key};
	#		say $key . ' ... ' . $value->();
	#	}
	#}
	cmpthese(@bench);
}

sub test_bench ($ref) {
	foreach my $href ($ref->[1]) {
		foreach my $key (keys %$href) {
			my $value = $href->{$key};
			say $key . ' ... ' . $value->();
		}
	}	
}
