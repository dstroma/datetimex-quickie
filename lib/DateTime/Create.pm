package DateTime::Create 0.001 {

	use v5.36;
	use DateTime ();
	use Regexp::Common 'number';
	use Try::Tiny;

	our $looks_like;
	our $force_parser;
	our $parser_used;

	our ($datetime_regex, @datetime_regex_capture_labels) = prepare_regex_and_labels();

	sub new {
		# This module is not meant to be its own class!
		die "new() is not a method of DateTime::Create";
	}

	sub create ($maybe_class, @params) {
		my $class = coerce_class($maybe_class);

		# Reset global debugging variables
		undef $looks_like;
		undef $parser_used;

		# A list
		if (@params > 1) {
			$looks_like = 'list';
			return new_from_list($class, @params);
		}

		my $param = $params[0];

		# An integer or real number looks like an epoch time
		if ($param =~ m/^$RE{num}{int}$/ or $param =~ m/^$RE{num}{real}$/) {
			$looks_like = 'epoch';
			return new_from_epoch($class, $param);
		}

		# If not a list, integer, or real, then it must be ISO datetime string
		$looks_like = 'iso_string';
		return new_from_iso_string($class, $param);

		# Doesn't look like any of the above
		#die(
		#	'Argument(s) to DateTime::Create->create do not resemble a supported pattern; ' .
		#	'expected datetime string, epoch number, or list'
		#);
	}

	sub new_from_list ($class, @params) {
		my $time_zone = extract_time_zone_from_params(\@params);
		my ($year, $month, $day, $hour, $minute, $second, $nanosecond) = @params;

		return $class->new(
			year   => $year,
			month  => $month  || 1,
			day    => $day    || 1,
			hour   => $hour   // 0,
			minute => $minute // 0,
			second => $second // 0,
			defined $nanosecond ? (nanosecond => $nanosecond) : (),
			$time_zone          ? (time_zone  => $time_zone)  : (),
		);
	}

	sub new_from_iso_string ($class, $string) {
		if ($force_parser) {
			return new_from_iso_string_internal($class, $string) if $force_parser eq 'internal';
			return new_from_iso_string_external($class, $string) if $force_parser eq 'external';
		}
			
		if (my $dt = new_from_iso_string_internal($class, $string)) {
			return $dt;
		}
		if (my $dt = new_from_iso_string_external($class, $string)) {
			return $dt;
		}

		die "DateTime::Create::create is unable to parse datetime string $string";
	}

	sub new_from_iso_string_internal ($class, $string) {	
		if (my (@capture) = $string =~ m/$datetime_regex/) {
			$parser_used = 'internal';

			my %capture;
			$capture{$datetime_regex_capture_labels[$_]} = $capture[$_] for 0..$#datetime_regex_capture_labels;

			my $nanosecond;
			if ($capture{'second_fraction'}) {
				$capture{'second_fraction'} =~ s`^,`\.`; # relace comma with dot
				$nanosecond = $capture{'second_fraction'} * 1_000_000_000;
			}

			my $obj = $class->new(
				year   => $capture{'year'},
				month  => $capture{'month'},
				day    => $capture{'day'},
				hour   => $capture{'hour'},
				minute => $capture{'minute'},
				second => $capture{'second'},
				$nanosecond       ? ( nanosecond => $nanosecond ) : (),
				$capture{'zulu'}  ? ( time_zone  => 'UTC' ) : (),
			);

			# Detect error if both zulu and offset are set
			# The regex should not allow this to happen, but this code might be
			# useful for debugging
			if ($capture{'zulu'} and $capture{'offset'}) {
				die(
					"DateTime::Create::new_from_iso_string argument $string " .
					'should not specify both Z and a timezone offset ' .
					'(should be one or the other)'
				);
			}

			if ($capture{'offset'}) {
				# DateTime::TimeZone does not take offsets < 4 digits (excluding +/-)
				my $offset = $capture{'offset'};
				$offset = "0$offset:00" if $offset =~ m/^[+-]\d$/;
				$offset = "$offset:00"  if $offset =~ m/^[+-]\d\d$/;
				$obj->set_time_zone($offset);
			}

			return $obj;
		}
	}

	sub new_from_iso_string_external ($class, $string) {
		my $dt;
		try {
			require DateTime::Format::ISO8601;
			$dt = DateTime::Format::ISO8601->parse_datetime($string);
			unless (ref $dt eq $class) {
				bless $dt, $class;
			}
		};

		if ($dt) {
			$parser_used = 'external';
			return $dt;
		} else {
			return undef;
		}
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

	sub import {
		require DateTime;
		no warnings 'once';
		*DateTime::create = \&create;
	}

	sub coerce_class ($class) {
		# We want to use the correct class if used on a subclass of DateTime
		# If class is the package name of this module, we change it to DateTime
		# because this module does not subclass DateTime
		if ($class eq __PACKAGE__) {
			return 'DateTime';
		}

		if ($class->isa('DateTime')) {
			return $class;
		}

		return 'DateTime';
	}

	sub prepare_regex_and_labels () {
		my $date         = '(\d\d\d\d)-(\d\d)-(\d\d)';
		my $separator    = '[T\s]';
		my $time         = '(\d\d):(\d\d):(\d\d)([\.,]\d+)?';
		my $maybe_tzone  = '(?:(Z|UTC)|([+-]\d\d|[+-]\d\d[:]?\d\d))?';
		my $regex        = qr/^$date$separator$time$maybe_tzone$/;

		my @labels = qw(
			year month day
			hour minute second second_fraction
			zulu offset
		);

		return ($regex, @labels);
	}
}

1;

=head1 NAME

DateTime::Create - a convenient, "do what I mean" way to create new DateTime
objects.

=head1 SYNOPSIS

	use DateTime::Create; # adds create() method to DateTime
	my $dt1 = DateTime->create(2023, 03, 01, 0, 0, 0, 'America/Chicago');
	my $dt2 = DateTime->create(scalar time);
	my $dt3 = DateTime->create('1978-07-04 20:18:45');

Or

	use DateTime::Create ();  # will avoid monkeypatching the DateTime module
	require DateTime::Create; # also avoids monkeypatching
	my $dt = DateTime::Create->create(...) 

=head1 DESCRIPTION

This module offers a create() class method that can be exported into the
DateTime namespace. It may also be used without exporting anything. It
returns new DateTime objects.

The motivation behind this module is the verbosity of creating DateTime objects:

	my $datetime = DateTime->new(
		year => 2000,
		month => 1,
		day => 1,
		hour => 0,
		minute => 0,
		second => 0
	);

DateTime does not parse date strings; users are instead directed to CPAN to
choose from a bewildering array of other modules to do this.

This module takes a "do what I mean" approach and attempts to parse datetimes
passed as either a list, an epoch time, or an ISO-style string.

=head1 SUBCLASSING DATETIME

If you normally use your own sublass of DateTime, this method will try to
return objects of the correct class. In other words,

	package My::DateTime { use parent 'DateTime'; }
	use DateTime::Create;
	my $obj = My::DateTime->create(...); # returns a My::DateTime object

=head1 PUBLIC METHODS

There is only one method intended for public consumption, which is the
create() class method. It can be used with three different kinds of arguments.

=item create(list)

A list is interpreted as containing elements necessary to create a DateTime in 
descending order, in other words, year, month, day, hour, minute, second,
and optional nanosecond, in that order.

Optionally, a time_zone name may be supplied at the beginning or end of the list.
This string will be checked using the DateTime::TimeZone->is_valid_name method.

	$dt = DateTime->create(2020, 01, 01, 8, 30, 0, 'America/Chicago');
	# 2020-01-01T08:30:00

Only the year must be defined. The remaining elements may be undef or missing
(except that at least two elements are needed to distinguish it as a list), in
which case the default month and day are 1, while the default hour, minute, and
second are 0. 

	$dt = DateTime->create(2020, undef); # 2020-01-01T00:00:00
	$dt = DateTime->create(2020);        # 1970-01-01T00:33:40 (2,020 seconds from epoch)

=item create(number)

An integer or float is interpreted as an epoch time and is passed directly
to DateTime's from_epoch() class method.

=item create(string)

If the argument to create() is neither a list nor a number, it is assumed to
be an ISO8601 style date string.

This module will try to parse strings it thinks are ISO 8601 datetimes using
its own internal parser (regex). It will match any forms like the following
(the separator between the date and time may be a space or the letter T):

	YYYY-MM-DD HH:MM:SS
	YYYY-MM-DD HH:MM:SS.ssssss
	YYYY-MM-DD HH:MM:SSZ
	YYYY-MM-DD HH:MM:SS[+-]NN
	YYYY-MM-DD HH:MM:SS[+-]NN:NN

The internal parser cannot handle unusual cases, such as dates before year 0000
or after year 9999, for example.

If unsuccessful, the module DateTime::Format::ISO8601 is used (if available)
to attempt to parse it instead.

Strangely the DateTime::Format::ISO8601 module will not parse a two-digit offset
value or an offset value with no separator between the hours and minutes.

=back

=head1 DEBUGGING

The following package globals may assist in debugging.

=over 4

=item $DateTime::Create::looks_like

What the module thinks the most recent argument type was. Contains one of the
strings 'list', 'epoch', or 'iso'. May be undef.

=item $DateTime::Create::parser_used

If used to parse an ISO-style string, may be 'internal' or 'external', with
'external' referring to DateTime::Format::ISO8601;

=item $DateTime::Create::force_parser

If this variable equals the string 'internal' or 'external', the create() method
will only attempt to use only the corresponding parser (as described above). The
default is undef, which will favor the internal parser.

=back

=head1 DEPENDENCIES

=over 4

=item perl v5.36 or greater

This module uses Perl's new native subroutine signatures. While it's a trivial
module that could have easily been written for a (much) older version, I believe
it is in the community's interest to encourage people to upgrade.

=item Regexp::Common

=item DateTime

=item Try::Tiny

=item Test::More for the test suite

=back

=head1 AUTHOR
 
Dondi Michael Stroma, E<lt>dstroma@gmail.comE<gt>
 
=head1 COPYRIGHT AND LICENSE
 
Copyright (C) 2023 by Dondi Michael Stroma
 
This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
 
=cut
