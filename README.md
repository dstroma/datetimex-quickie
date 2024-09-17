# NAME

DateTimeX::Quickie - Extend DateTime by adding a convenient quickie() method.

# SYNOPSIS

        use DateTimeX::Quickie;

        # Create from list
        my $dt1 = DateTime->quickie(2023, 03, 01, 0, 0, 0, 'America/Chicago');

        # Create from epoch time
        my $dt2 = DateTime->quickie(time);

        # Create from string
        my $dt3 = DateTime->quickie('1978-07-04 20:18:45');

# DESCRIPTION

This module offers a quickie() class method that can be exported into DateTime
or another specified module. It may also be used without exporting anything. It
returns new DateTime objects or objects from a DateTime-compatible class.

This module takes a "do what I mean" approach and attempts to parse datetimes
passed as either a list, arrayref, an epoch time, or an ISO8601-like string.

The most simple use is to call DateTime->quickie with no arguments which returns
a DateTime object equivalent to 0000-01-01 00:00:00.

# JUSTIFICATION

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

# EXPORTING

By default this module exports the quickie() method to the DateTime package.
You can specify that this module exports the method to a different
namspace, and objects returned will be instances of the correct class:

        use DateTimeX::Quickie (export_to => 'DateTime::Moonpig');
        DateTime::Moonpig->quickie(...); # returns DateTime::Moonpig object

Or you can choose to not export anything:

        use DateTimeX::Quickie ();                       # export nothing
        DateTimeX::Quickie->quickie(...);                # returns DateTime object
        DateTimeX::Quickie::quickie('My::DateTime', ...) # returns My::DateTime object

Exporting to multiple different namespaces is best done by calling import
directly:

        require DateTimeX::Quickie;
        DateTimeX->import(export_to => 'My::DateTime::Class');
        DateTimeX->import(export_to => 'My::Other::DateTime::Class');

Note that this module does NOT export anything to the caller's namespace. In
other words the following will not work:

        use DateTimeX::Create qw(create); # error

        package My::Module {
                use DateTimeX::Create;
                create(...)               # error
        }
        My::Module->create(...)           # error

# PUBLIC METHODS

There is only one method intended for public consumption, which is the
create() class method. It can be used with three different kinds of arguments.

- create(list) OR create(arrayref)

    A list is interpreted as containing elements necessary to create a DateTime in 
    descending order, in other words, year, month, day, hour, minute, second,
    and optional nanosecond, in that order.

    Optionally, a time\_zone name may be supplied at the beginning or end of the list.
    This string will be checked using the DateTime::TimeZone->is\_valid\_name method.

            $dt = DateTime->create(2020, 01, 01, 8, 30, 0, 'America/Chicago');
            # 2020-01-01T08:30:00

    The default year is 0. The default month and day are 1. The default hour,
    minute, and second are 0.

    In create(list) form, either zero or more than one element is required (as
    a single element would be interpreted as a string or seconds since epoch), but
    any element may be undef.

    In create(arrayref) form, all elements may be undef or
    missing.

            $dt = DateTime->create;               # 0000-01-01T00:00:00
            $dt = DateTime->create([]);           # same
            $dt = DateTime->create(undef, undef); # same
            $dt = DateTime->create(2020,  undef); # 2020-01-01T00:00:00

    Be careful not to supply just a year in list form, as this is interpreted as
    an epoch time:

            $dt = DateTime->create(2020); # 1970-01-01T00:33:40

- create(number)

    An integer or float is interpreted as an epoch time and is passed directly
    to DateTime's from\_epoch() class method.

- create(string)

    If the argument to create() is neither a list nor a number, it is assumed to
    be an ISO8601 style date string.

    This module will try to parse strings it thinks are ISO 8601 datetimes using
    its own internal parsing regex. It will match any forms like the following
    (the separator between the date and time may be a space or the letter T):

            YYYY-MM-DD HH:MM:SS
            YYYY-MM-DD HH:MM:SS.ssssss
            YYYY-MM-DD HH:MM:SSZ
            YYYY-MM-DD HH:MM:SS[+-]NN
            YYYY-MM-DD HH:MM:SS[+-]NN:NN

    The returned DateTime will have its time\_zone set to the floating timezone, or
    offset-only timezone, as appropriate.

    The internal parser cannot handle unusual cases, such as dates before year 0000
    or after year 9999, for example.

    If unsuccessful, the module DateTime::Format::ISO8601 is used (if available)
    to attempt to parse it instead.

# DEBUGGING

The following package globals may assist in debugging.

- $DateTimeX::Create::looks\_like

    What this module thinks the most recent argument type was. Contains one of the
    strings 'empty', 'list', 'arrayref', 'epoch', or 'iso\_string'. May be undef.

- $DateTimeX::Create::parser\_used

    If used to parse an ISO-style string, may be 'internal' or 'external', with
    'external' referring to DateTime::Format::ISO8601;

- $DateTimeX::Create::force\_parser

    If this variable equals the string 'internal' or 'external', the create() method
    will only attempt to use only the corresponding parser (as described above). The
    default is undef, which will favor the internal parser.

# DEPENDENCIES

- perl v5.36 or greater

    This is primarily for native subroutine signatures. 

- DateTime
- Try::Tiny
- Test::More for the test suite

# SEE ALSO

- [DateTime::Auto](https://metacpan.org/pod/DateTime%3A%3AAuto)
- [DateTime::Easy](https://metacpan.org/pod/DateTime%3A%3AEasy)
- [DateTime::Format::DateParse](https://metacpan.org/pod/DateTime%3A%3AFormat%3A%3ADateParse)
- [DateTime::Moonpig](https://metacpan.org/pod/DateTime%3A%3AMoonpig)

    DateTime::Moonpig is a wrapper around DateTime that prevents accidentally
    mutating existing objects, which can result at action-at-a-distance bugs.

# AUTHOR

Dondi Michael Stroma, <dstroma@gmail.com>

# COPYRIGHT AND LICENSE

Copyright (C) 2023 by Dondi Michael Stroma

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
