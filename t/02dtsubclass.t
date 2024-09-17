#!perl

use v5.36;
use Test::More;
use DateTimeX::Quickie;

package My::Test::DateTime::Subclass {
	use parent 'DateTime';
}

package My::Fake::DateTime::Class {
	use DateTimeX::Quickie (export_to => __PACKAGE__);
	sub new {
		my $class = shift;
		bless {}, $class
	}
}

my $obj;
ok($obj = My::Test::DateTime::Subclass->quickie(2020, 1, 1), 'Call quickie() on a subclass of DateTime');
is(ref $obj => 'My::Test::DateTime::Subclass',              'object returned is correct class');

ok($obj = My::Fake::DateTime::Class->quickie(2020, 1, 1),    'Call quickie() on a subclass of DateTime');
is(ref $obj => 'My::Fake::DateTime::Class',                 'object returned is correct class');

done_testing();

