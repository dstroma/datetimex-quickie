package DateTime::Create 0.001 {

	use v5.36;
	use Regexp::Common 'number';
	use Try::Tiny;

	our $looks_like;
	our $force_iso_parser;
	our $parser_used;

	our ($datetime_regex, @datetime_regex_capture_labels) = prepare_regex_and_labels();

	sub new {
		# This module is not meant to be its own class!
		die "new() is not a method of DateTime::Create";
	}

	sub create ($maybe_class, @params) {
		my $class = coerce_class($maybe_class);

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
		if ($force_iso_parser) {
			return new_from_iso_string_internal($class, $string) if $force_iso_parser eq 'internal';
			return new_from_iso_string_external($class, $string) if $force_iso_parser eq 'external';
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
		} catch {
			warn $_;
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
	my $dt = DateTime::Create->create(...) 

or

	require DateTime::Create;
	my $dt = DateTime::Create->create(...)

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

This module will try to parse strings it thinks are ISO 8601 datetimes using
its own internal parser (regex) if it matches forms like the following
(the separator between the date and time may be a space or the letter T):

	YYYY-MM-DD HH:MM:SS
	YYYY-MM-DD HH:MM:SS.ssssss
	YYYY-MM-DD HH:MM:SSZ
	YYYY-MM-DD HH:MM:SS[+-]NN
	YYYY-MM-DD HH:MM:SS[+-]NN:NN

The internal parser cannot handle uncommon cases, such as dates before year 0000
or after 9999, for example.

If unsuccessful, the module DateTime::Format::ISO8601 is used (if available)
to attempt to parse it instead.

Strangely the DateTime::Format::ISO8601 module will not parse a two-digit offset
value or an offset value with no separator between the hours and minutes.

epoch

An integer or real number. Passed to DateTime's from_epoch method without much
processing.

DEPENDENCIES

Regexp::Common
DateTime
barewords

