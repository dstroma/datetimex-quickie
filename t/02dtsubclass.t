#!perl

use v5.36;
use Test::More;
use DateTime::Create;

package Tmp::My::Test::DateTime::Subclass {
	use parent 'DateTime';
}

my $obj;
ok($obj = Tmp::My::Test::DateTime::Subclass->create(2020, 1, 1), 'Call create() on a subclass of DateTime');
is(ref $obj => 'Tmp::My::Test::DateTime::Subclass', 'object returned is correct class');

done_testing();

