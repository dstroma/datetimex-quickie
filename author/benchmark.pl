#!perl

use v5.36;
use DateTimeX::Create;
use DateTime::Format::ISO8601;
use Benchmark 'cmpthese';
use constant ITERATIONS => 30_000;

my $dtstring = '1957-12-31T05:06:07.83739+0230';

my @bench1 = (ITERATIONS, {
  'string_inline_c' => sub { my $dt = DateTimeX::Create::new_from_c('DateTime', $dtstring); },
  'string_internal' => sub { my $dt = DateTimeX::Create::new_from_iso_string_internal('DateTime', $dtstring); },
  'string_external' => sub { my $dt = DateTimeX::Create::new_from_iso_string_external('DateTime', $dtstring); },
  'string_auto'     => sub { my $dt = DateTimeX::Create::new_from_iso_string('DateTime', $dtstring); },
  }
);

my @bench2 = (ITERATIONS, {
  'empty_list'     => sub { my $dt = DateTime->create(); },
  'empty_arrayref' => sub { my $dt = DateTime->create([]); },
  }
);

my @bench3 = (ITERATIONS, {
  'raw DateTime->new' => sub { my $dt = DateTime->new(year => 2012, month => 7, day => 4, hour => 12, minute => 30, second => 0); },
  'list'   => sub { my $dt = DateTime->create(2012, 07, 04, 12, 30, 0); },
  'string' => sub { my $dt = DateTime->create('2012-07-04T12:30:00'); },
  }
);

say "\nBenchmark 1: String parsing";
cmpthese(@bench1);

say "\nBenchmark 2: empty list/empty arrayref";
cmpthese(@bench2);

say "\nBenchmark 3: list v. string";
cmpthese(@bench3);

