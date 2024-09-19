#!perl

use v5.36;
use Test::More;
use DateTime;

# Test - load module with 'require' (so we don't call import yet)
require_ok('DateTimeX::Quickie');

# Method should not exist yet in DateTime
eval 'use DateTimeX::Quickie ()';
ok(
	not(DateTime->can('quickie')),
	'DateTime should not have a quickie() method yet'
);

# Import
ok(
	eval 'DateTimeX::Quickie->import; 1',
	'Import DateTimeX::Quickie'
);

# Method should exist in DateTime
ok(
	DateTime->can('quickie'),
	'Now DateTime should have a quickie() method'
);

# After import, DateTimeX::Quickie::quickie should equal DateTime::quickie
ok(
	\&DateTimeX::Quickie::quickie eq \&DateTime::quickie,
	'DateTime::quickie should equal DateTimeX::Quickie::quickie'
);

# DTC->new should not equal DT->new
ok(
	\&DateTimeX::Quickie::new ne \&DateTime::new,
	'DateTime::new should not equal DateTimeX::Quickie::new'
);

# Export to a different class
ok(
	eval q`DateTimeX::Quickie->import(export_to => 'My::Test::Class'); 1`,
	'Export to a different class'
);
is(
	\&DateTimeX::Quickie::quickie => \&My::Test::Class::quickie,
	'Confirm successfully exported'
);

# Invalid use lines should result in error
ok(
	not(eval "use DateTimeX::Quickie qw(quickie); 1;"),
	'Confirm `use DateTimeX::Quickie qw(quickie)` throws error'
);
ok(
	not(eval "use DateTimeX::Quickie ('new'); 1;"),
	'Confirm invalid params to import throws error'
);
ok(
	not(eval "use DateTimeX::Quickie ('quickie', 'quickie'); 1;"),
	'Confirm invalid params to import throws error'
);
ok(
	not(eval "use DateTimeX::Quickie ('quickie', 'new'); 1;"),
	'Confirm invalid params to import throws error'
);


done_testing();
