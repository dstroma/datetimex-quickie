#!perl
use v5.36;
use Test::More;

# First test group - export quickie to a specific package
{
  package My::Fake::DateTime::Class {
    use DateTimeX::Quickie (export_to => __PACKAGE__);
    sub new {
      my $class = shift;
      bless {}, $class
    }
  }
  my $obj;
  ok($obj = My::Fake::DateTime::Class->quickie(2020, 1, 1),    'Can call quickie() on a subclass of DateTime');
  is(ref $obj => 'My::Fake::DateTime::Class',                  'Object returned is correct class');
  ok(not(DateTime->can('quickie')),                            'DateTime base class is not modified');
}

# Second test group - make sure it's not exported where it's not supposed to
{
  package My::Test::DateTime::Subclass1 {
    use parent 'DateTime';
  }
  my $obj;
  ok(not(eval { $obj = My::Test::DateTime::Subclass->quickie(2020, 1, 1); 1 }), 'Call quickie() on a subclass of DateTime');
}

# Third test group - make sure it's exported and subclassable
{
  package My::Test::DateTime::Subclass2 {
    eval "use DateTimeX::Quickie; 1" or die 'Unexpcted error during testing';
    use parent 'DateTime';
  }
  my $obj;
  ok($obj = My::Test::DateTime::Subclass2->quickie(2020, 1, 1),    'Can call quickie() on a subclass of DateTime');
  is(ref $obj => 'My::Test::DateTime::Subclass2',                  'Object returned is correct class');
}

done_testing();
