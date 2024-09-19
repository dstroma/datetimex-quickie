package DateTimeX::Quickie 0.001 {

	use v5.36;
	use feature 'try';
	use Carp;

	our ($looks_like, $parser_used);
	my  ($number_regex, $datetime_regex, @datetime_regex_capture_labels);
	prepare_regex_and_labels();

	sub new ($self_class, $target_class, @params) {
		return quickie($target_class, @params);
	}

	sub quickie ($maybe_class, @params) {
		my $class = coerce_class($maybe_class);

		# Reset global debugging variables
		undef $looks_like;
		undef $parser_used;

		# Is it empty?
		if (@params == 0) {
			$looks_like = 'empty';
			return new_from_empty($class);
		}

		# Is it 'now'?
		elsif ($params[0] eq 'now') {
			return new_now($class);
		}

		# Is it a list?
		elsif (@params > 1) {
			$looks_like = 'list';
			return new_from_list($class, @params);
		}

		# Is it an arrayref?
		elsif (ref $params[0] and ref $params[0] eq 'ARRAY') {
			$looks_like = 'arrayref';
			return new_from_arrayref($class, $params[0]);
		}

		# Is it a hashref?
		elsif (ref $params[0] and ref $params[0] eq 'HASH') {
			$looks_like = 'hashref';
			return new_from_hashref($class, $params[0]);
		}

		# Is it an integer or real number (epoch)?
		elsif ($params[0] =~ $number_regex) {
			$looks_like = 'epoch';
			return new_from_epoch($class, $params[0]);
		}

		# If not a list, integer, or real, then it must be ISO datetime string
		$looks_like = 'iso_string';
		return new_from_iso_string($class, $params[0]);
	}

	sub new_from_empty ($class) {
		return $class->new(year=>0, month=>1, day=>1, hour=>0, minute=>0, second=>0);
	}

	sub new_from_list ($class, @params) {
		if (@params % 2 == 0) {
			my $first = $params[0];
			if ($first =~ m/^year|month|day|hour|minute|second|nanosecond|time_zone$/) {
				my %params = @params;
				return new_from_hashref($class, \%params);
			}
		}
		return new_from_arrayref($class, \@params);
	}

	sub new_from_arrayref ($class, $params) {
		my $time_zone = extract_time_zone_from_params($params);
		my ($year, $month, $day, $hour, $minute, $second, $nanosecond) = @$params;

		if ($second and not $nanosecond) {
			($second, $nanosecond) = seconds_to_seconds_and_nanoseconds($second);
		}

		return $class->new(
			year       => $year       // 0,
			month      => $month      || 1,
			day        => $day        || 1,
			hour       => $hour       // 0,
			minute     => $minute     // 0,
			second     => $second     // 0,
			nanosecond => $nanosecond // 0,
			$time_zone ? (time_zone  => $time_zone) : (),
		);
	}

	sub new_from_hashref ($class, $r) {
		return $class->new(
			year       => $r->{year}   // 0,
			month      => $r->{month}  || 1,
			day        => $r->{day}    || 1,
			hour       => $r->{hour}   // 0,
			minute     => $r->{minute} // 0,
			second     => $r->{second} // 0,
			nanosecond => $r->{nanosecond} // 0,
			$r->{time_zone} ? (time_zone => $r->{time_zone}) : (),
		);
	}

	sub new_from_iso_string ($class, $string) {
		if (my $dt = new_from_iso_string_internal($class, $string)) {
			return $dt;
		}
		if (my $dt = new_from_iso_string_external($class, $string)) {
			return $dt;
		}
		croak qq{Unable to parse ISO-like datetime string "$string"};
	}

	sub new_from_iso_string_internal ($class, $string) {
		if (my (@capture) = $string =~ m/$datetime_regex/) {
			$parser_used = 'internal';

			my %capture;
			$capture{$datetime_regex_capture_labels[$_]} = $capture[$_] for 0..$#datetime_regex_capture_labels;

			my $second     = $capture{'second'};
			my $nanosecond = 0;
			if ($capture{'second_fraction'}) {
				my $frac = substr($capture{'second_fraction'}, 1); # eliminate decimal point
				($second, $nanosecond) = seconds_to_seconds_and_nanoseconds($second . '.' . $frac);
			}

			my $obj = $class->new(
				year       => $capture{'year'},
				month      => $capture{'month'},
				day        => $capture{'day'},
				hour       => $capture{'hour'},
				minute     => $capture{'minute'},
				second     => $second,
				nanosecond => $nanosecond,
				$capture{'zulu'}  ? ( time_zone  => 'UTC' ) : (),
			);

			# Detect error if both zulu and offset are set
			# The regex should not allow this to happen, but this code might be
			# useful for debugging
			if ($capture{'zulu'} and $capture{'offset'}) {
				croak(
					"DateTimeX::Quickie::new_from_iso_string argument $string " .
					'cannot specify both "Z" and a timezone offset '
				);
			}

			if ($capture{'offset'}) {
				# DateTime::TimeZone requires offsets to include minutes
				my $offset = $capture{'offset'};
				$offset = "0$offset:00" if $offset =~ m/^[+-]\d$/;
				$offset = "$offset:00"  if $offset =~ m/^[+-]\d\d$/;
				$obj->set_time_zone($offset);
			}

			return $obj;
		}
		return undef;
	}

	sub new_from_iso_string_external ($class, $string) {
		my $dt;
		try {
			require DateTime::Format::ISO8601;
			$dt = DateTime::Format::ISO8601->parse_datetime($string);
		} catch ($e) {
			carp "Unable to parse datetime string '$string'";
			return undef;
		}
		if ($dt) {
			bless $dt, $class unless ref $dt eq $class;
			$parser_used = 'external';
			return $dt;
		}
		return undef;
	}

	sub new_from_epoch ($class, $epoch) {
		return $class->from_epoch($epoch);
	}

	sub extract_time_zone_from_params ($params_ref) {
		return shift @$params_ref if is_valid_time_zone_name($params_ref->[ 0]);
		return pop   @$params_ref if is_valid_time_zone_name($params_ref->[-1]);
	}

	sub is_valid_time_zone_name ($name) {
		# All tz names have at least 2 letters
		if ($name and $name =~ m/[a-zA-Z]{2}/ ) {
			require DateTime::TimeZone;
			return DateTime::TimeZone->is_valid_name($name);
		}
		return undef;
	}

	sub seconds_to_seconds_and_nanoseconds ($second) {
		my $nanosecond;
		# Nanosecond handling derived from DateTime::Format::DateParse
		if (my $fraction = $second - int $second) {
			$nanosecond = $fraction * 1e9;
			if (my $nanofraction = $nanosecond - int $nanosecond) {
				$nanosecond = int $nanosecond;
				$nanosecond++ if $nanofraction >= 0.5;
			}
			$second = int $second;
			return ($second, $nanosecond);
		}
		return ($second, 0);
	}

	sub import ($self_class, @params) {
		state $help = 
			'Valid uses:'.
			'	use DateTimeX::Quickie;    # automatically export to DateTime'.
			'	use DateTimeX::Quickie (); # no export'.
			'	use DateTimeX::Quickie (export_to => "My::Module"); # export to specified module';

		# Determine where to export
		my $export_to = 'DateTime';
		if (@params) {
			croak $help unless $params[0] eq 'export_to' and @params == 2;
			$export_to = $params[1];
		}
		__PACKAGE__->export_to($export_to);
	}

	sub export_to ($self_class, $export_to) {
		state %exported;
		return 1 if $exported{$export_to}; # Already exported
		require DateTime if $export_to eq 'DateTime';
		no warnings 'once';
		no strict 'refs';
		*{$export_to . '::quickie'} = \&quickie;
		$exported{$export_to} = 1;
	}

	sub coerce_class ($class) {
		# We want to use the correct class if used on a subclass of DateTime
		# If class is the package name of this module, we change it to DateTime
		# because this module does not subclass DateTime
		return 'DateTime' if $class eq __PACKAGE__;
		return $class     if $class and length $class;
		return 'Datetime';
	}

	sub prepare_regex_and_labels () {
		my $date         = '(\d\d\d\d)-(\d\d)-(\d\d)';
		my $separator    = '[T\s]';
		my $time         = '(\d\d):(\d\d):(\d\d)([\.,]\d+)?';
		my $maybe_tzone  = '(?:(Z|UTC)|([+-]\d\d|[+-]\d\d[:]?\d\d))?';

		$datetime_regex = qr/^$date$separator$time$maybe_tzone$/;
		@datetime_regex_capture_labels = qw(year month day hour minute second second_fraction zulu offset);
		$number_regex = qr/^[+-]?\d+(\.\d+)?$/;
		return 1;
	}
}

1;

=head1 NAME

DateTimeX::Quickie - Extend DateTime by adding a convenient quickie() method.


=head1 SYNOPSIS

	# Default export 'quickie' to 'DateTime'
	use DateTimeX::Quickie;

	# Create from list of values (or arrayref)
	my $dt1 = DateTime->quickie(2023, 03, 01, 0, 0, 0, 'America/Chicago');

	# Create from key-value pairs (or hashref) (specify at least 1 pair)
	my $dt2 = DateTime->quickie(year => 2023); # 1 Jan 2023 00:00:00

    # Epoch time
	my $dt3 = DateTime->quickie(946684800); # 1 Jan 2000

    # ISO8601-like string (with space or 'T' between date and time)
	my $dt4 = DateTime->quickie('1978-07-04 20:18:45');

	# Alternate interface with no export
	use DateTimeX::Quickie ();
	my $dt5 = DateTimeX::Quickie->new(DateTime => '2024-01-01 00:00:00');
	my $dt6 = DateTimeX::Quickie->new('My::DateTime' => $string);


=head1 DESCRIPTION

The purpose of this module is to be able to create DateTime objects (or objects
of a DateTime-like class) quickly with little typing.

By default, the quickie() method is exported to the DateTime package. You can
also export to a different package, or not export anything ata all.

This module takes a "do what I mean" approach and attempts to parse datetimes
passed as either a list, arrayref, hashref, an epoch number, or an ISO8601-like
string.

The most simple use is to call with no arguments which returns an object
equivalent to 0000-01-01 00:00:00.


=head1 JUSTIFICATION

The motivation behind this module is the verbosity of creating DateTime objects:

	my $datetime = DateTime->new(
		year => 2000,
		month => 1,
		day => 1,
		hour => 0,
		minute => 0,
		second => 0
	);

That is a lot of typing just to create one datetime object. Since the DateTime
module does not parse date strings, users are instead directed to CPAN to
choose from a bewildering array of other modules to do this for them.

There are some other similar modules on CPAN such as DateTimeX::Auto,
DateTimeX::Easy, and DateTime::Format::DateParse. 

Unlike these other modules, this one can be used on subclasses of DateTime
(or even a completely different class with a DateTime-like interface) and
will return objects already blessed into the correct class. See the EXPORTING
section below for more information on that.

Why have a "safe" way and a "dangerous" way? Because the whole point of this
module is to save typing.

	my $datetime = DateTime->quickie($arg);

Is less typing than

	my $datetime = DateTimeX::Quickie->new('DateTime' => $arg);


=head1 EXPORTING

Important! This module is not a subclass of DateTime!

By default this module exports the quickie() method to the DateTime package.
You can specify that this module exports to a different package, and
objects returned will be instances of the appropriate class:

	use DateTimeX::Quickie (export_to => 'DateTime::Moonpig');
	DateTime::Moonpig->quickie(...); # returns DateTime::Moonpig object

Or you can choose to not export anything. However, if you do this and call
new(), you MUST specify what kind of object you want.

	use DateTimeX::Quickie ();
	DateTimeX::Quickie->new('DateTime' => ...);

Exporting to multiple different namespaces is best done by calling import
directly or using the more semantic export_to class method.

	require DateTimeX::Quickie;
	DateTimeX::Quickie->import(export_to => 'My::DateTime::Class');
	DateTimeX::Quickie->export_to('Another::DateTime::Class');

This module does NOT export anything to the caller's namespace!

	use DateTimeX::Quickie qw(quickie); # error

	package My::Module;
	use DateTimeX::Quickie;
	quickie(...) # error


=head1 PUBLIC METHODS

=over 4

=item quickie(list) OR quickie(arrayref)

A list is interpreted as containing elements necessary to create a DateTime in 
descending order, in other words, year, month, day, hour, minute, second,
and optional nanosecond, in that order.

Optionally, a time_zone name may be supplied at the beginning or end of the list.
This string will be checked using the DateTime::TimeZone->is_valid_name method.

	$dt = DateTime->quickie(2020, 01, 01, 8, 30, 0, 'America/Chicago');
	# 2020-01-01T08:30:00

The default year is 0. The default month and day are 1. The default hour,
minute, and second are 0.

In quickie(list) form, either zero or more than one element is required (as
a single element would be interpreted as a string or seconds since epoch), but
any element may be undef.

In quickie(arrayref) form, all elements may be undef or
missing.

	$dt = DateTime->quickie;               # 0000-01-01T00:00:00
	$dt = DateTime->quickie([]);           # same
	$dt = DateTime->quickie(undef, undef); # same
	$dt = DateTime->quickie(2020,  undef); # 2020-01-01T00:00:00

Be careful not to supply just a year in list form, as this is interpreted as
an epoch time:

	$dt = DateTime->quickie(2020); # 1970-01-01T00:33:40


=item quickie(number)

An integer or float is interpreted as an epoch time and is passed directly
to DateTime's from_epoch() class method.


=item quickie(string)

If the argument to quickie() is neither a list nor a number, it is assumed to
be an ISO8601 style date string.

This module will try to parse strings it thinks are ISO 8601 datetimes using
its own internal parsing regex. It will match any forms like the following
(the separator between the date and time may be a space or the letter T):

	YYYY-MM-DD HH:MM:SS
	YYYY-MM-DD HH:MM:SS.ssssss
	YYYY-MM-DD HH:MM:SSZ
	YYYY-MM-DD HH:MM:SS[+-]NN
	YYYY-MM-DD HH:MM:SS[+-]NN:NN

The returned DateTime will have its time_zone set to the floating timezone, or
offset-only timezone, as appropriate.

The internal parser cannot handle unusual cases, such as dates before year 0000
or after year 9999, for example.

If unsuccessful, the module DateTime::Format::ISO8601 is used (if available)
to attempt to parse it instead.


=back

=head1 DEBUGGING

The following package globals may assist in debugging.

=over 4

=item $DateTimeX::Quickie::looks_like

What this module thinks the most recent argument type was. Contains one of the
strings 'empty', 'list', 'arrayref', 'epoch', or 'iso_string'. May be undef.

=item $DateTimeX::Quickie::parser_used

If used to parse an ISO-style string, may be 'internal' or 'external', with
'external' referring to DateTime::Format::ISO8601;

=back

=head1 DEPENDENCIES

=over 4

=item perl v5.36 or greater

This is primarily for native subroutine signatures. 

=item Regexp::Common

=item DateTime

=item Test::More for the test suite

=back

=head1 SEE ALSO

=over 4

=item L<DateTimeX::Auto>

=item L<DateTimeX::Easy>

=item L<DateTime::Format::DateParse>

=item L<DateTime::Moonpig>

DateTime::Moonpig is a wrapper around DateTime that prevents accidentally
mutating existing objects, which can result at action-at-a-distance bugs.

=item :<DateTimeX::Immutable>

DateTimeX::Immutable is a newer implementation of an immutable DateTime
subclass.

=back

=head1 AUTHOR
 
Dondi Michael Stroma, E<lt>dstroma@gmail.comE<gt>
 
=head1 COPYRIGHT AND LICENSE
 
Copyright (C) 2023 by Dondi Michael Stroma
 
This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
 
=cut
