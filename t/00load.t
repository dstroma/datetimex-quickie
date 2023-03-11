#!perl

use v5.36;
use Test::More;
use Try::Tiny;
use DateTime;

# Test - load module with 'require' (so we don't call import yet)
require_ok('DateTimeX::Create');

# Method should not exist yet in DateTime
eval 'use DateTimeX::Create ()';
ok(
	not(DateTime->can('create')),
	'DateTime should not have a create() method yet'
);

# Import
ok(
	try { DateTimeX::Create->import; 1; },
	'Import DateTimeX::Create'
);

# Method should exist in DateTime
ok(
	DateTime->can('create'),
	'Now DateTime should have a create() method'
);

# After import, DateTimeX::Create::create should equal DateTime::create
ok(
	\&DateTimeX::Create::create eq \&DateTime::create,
	'DateTime::create should equal DateTimeX::Create::create'
);

# DTC->new should not equal DT->new
ok(
	\&DateTimeX::Create::new ne \&DateTime::new,
	'DateTime::new should not equal DateTimeX::Create::new'
);

# Export to a different class
ok(
	try { DateTimeX::Create->import(export_to => 'My::Test::Class'); 1; },
	'Export to a different class'
);
is(
	\&DateTimeX::Create::create => \&My::Test::Class::create,
	'Confirm successfully exported'
);

# Invalid use lines should result in error
ok(
	not(eval "use DateTimeX::Create qw(create); 1;"),
	'Confirm `use DateTimeX::Create qw(create)` throws error'
);
ok(
	not(eval "use DateTimeX::Create ('new'); 1;"),
	'Confirm invalid params to import throws error'
);
ok(
	not(eval "use DateTimeX::Create ('create', 'create'); 1;"),
	'Confirm invalid params to import throws error'
);
ok(
	not(eval "use DateTimeX::Create ('create', 'new'); 1;"),
	'Confirm invalid params to import throws error'
);


done_testing();

