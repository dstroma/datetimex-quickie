package DateTime::Create 0.001 {

	use v5.36;
	use Regexp::Common 'number';
	use barewords qw(list iso epoch);

	sub new ($self, @params) {
		return create('DateTime', @params);
	}

	sub create ($maybe_class, @params) {
		my $class = coerce_class($maybe_class);
		my $looks_like;

		if (@params > 1) {
			$looks_like = list;
			return new_from_list($class, @params);
		}

		my $param = $params[0];

		if ($param =~ m`^\d\d\d\d[-_\.\s]\d\d[-_\.\s]\d\d`) {
			$looks_like = iso;
			return $self->new_from_iso($class, $param);
		}

		if ($param =~ m/^$RE{num}{int}$/ or $pattern =~ m/^$RE{num}{real}$/)/ {
			$looks_like = epoch;
			return $self->new_from_epoch($class, $param);
		}
	}

	sub new_from_list ($class, @params) {
		my $time_zone = extract_time_zone_from_params(\@params);
		my ($year, $month, $day, $hour, $minute, $second, $nanosecond) = @params;

		return $class->new(
			year   => $year,
			month  => $month  // 1,
			day    => $day    // 1,
			hour   => $hour   // 0,
			minute => $minute // 0,
			second => $second // 0,
			defined $nanonsecond ? (nanosecond => $nanosecond) : (),
			$time_zone           ? (time_zone  => $time_zone)  : (),
		);

	}

	sub new_from_epoch ($class, $epoch) {
		return $class->from_epoch($epoch);
	}

	sub extract_time_zone_from_params ($params_ref) {
		require DateTime::TimeZone;
		return shift @$params_ref if DateTime::TimeZone->is_valid_name($params_ref->[ 0]);
		return pop   @$params_ref if DateTime::TimeZone->is_valid_name($params_ref->[-1]);
	}

	sub IMPORT {
		require DateTime;
		no warnings 'once';
		*DateTime::create = \&create;
	}

	sub coerce_class ($class) {
		# We want to use the correct class if called on a subclass of DateTime
		# If class is equal to the package name of this module, we change it to DateTime
		# because this module does not subclass DateTime, only adds methods to it
		if ($class eq __PACKAGE__) {
			return 'DateTime';
		}

		if ($class->isa('DateTime') {
			return $class;
		}

		return 'DateTime';
	}
}

1;

=pod

Synopsis:

This module adds a 'create' method to DateTime.

	use DateTime::Create;
	my $dt1 = DateTime->create(2023, 03, 01, 0, 0, 0, 'America/Chicago');
	my $dt2 = DateTime->create(scalar time);
	my $dt3 = DateTime->create('1956-07-11 00:00:00');

Alternatively, if you would rather avoid the monkeypatching of DateTime, you can
load this module without calling import and then use its create method (or new
method if you prefer). Simply pass an empty list to the use function:

	use DateTime::Create (); # no import
	my $dt = DateTime::Create->create(...) # or ->new(...)

or

	require DateTime::Create;
	my $dt = DateTime::Create->create(...) # or ->new(...)

The create method attempts to 'do the right thing' with the parameter(s) it is
given. The options are:

list

A list is interpreted as all of the elements necessary to create a DateTime in 
descending order, in other words, year, month, day, hour, minute, second,
and optionall nanosecond, in that order.

Only the year is required. The default month and day are 1, while the default
hour, minute, and second are 0.

Optionally, a time_zone string may be supplied at the beginning or end of the list.
This string will be checked using the DateTime::TimeZone->is_valid_name method.

iso

A string in the form of YYYY-MM-DD HH:MM:SS or similar.

epoch

An integer or real number. Passed to DateTime's from_epoch method.

