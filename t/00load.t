#!perl

use v5.36;
use Test::More;
use Try::Tiny;
use DateTime;

# Test - load module with 'require' (so we don't call import yet)
require_ok('DateTime::Create');

# Method should not exist yet in DateTime
eval 'use DateTime::Create ()';
ok(
	not(DateTime->can('create')),
	'DateTime should not have a create() method yet'
);

# Import
ok(
	try { DateTime::Create->import; 1; },
	'Import DateTime::Create'
);

# Method should exist in DateTime
ok(
	DateTime->can('create'),
	'Now DateTime should have a create() method'
);

# After import, DateTime::Create::create should equal DateTime::create
ok(
	\&DateTime::Create::create eq \&DateTime::create,
	'DateTime::create should equal DateTime::Create::create'
);

# DTC->new should not equal DT->new
ok(
	\&DateTime::Create::new ne \&DateTime::new,
	'DateTime::new should not equal DateTime::Create::new'
);

done_testing();

