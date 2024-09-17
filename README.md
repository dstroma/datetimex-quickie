# NAME

DateTimeX::Quickie - Extend DateTime by adding a convenient quickie() method.

# SYNOPSIS

        # Default export 'quickie' to 'DateTime'
        use DateTimeX::Quickie;

        # Create from list, epoch, or ISO string
        my $dt1 = DateTime->quickie(2023, 03, 01, 0, 0, 0, 'America/Chicago');
        my $dt2 = DateTime->quickie(946684800); # 1 Jan 2000
        my $dt3 = DateTime->quickie('1978-07-04 20:18:45');

        # Alternate interface with no export
        use DateTimeX::Quickie ();
        my $dt4 = DateTimeX::Quickie->new(DateTime => '2024-01-01 00:00:00');
        my $dt4 = DateTimeX::Quickie->new('My::DateTime' => $string);

# DESCRIPTION

The purpose of this module is to be able to create DateTime objects (or objects
of a DateTime-like class) quickly with little typing.

By default, the quickie() method is exported to the DateTime package. You can
also export to a different package, or not export anything ata all.

This module takes a "do what I mean" approach and attempts to parse datetimes
passed as either a list, arrayref, an epoch time, or an ISO8601-like string.

The most simple use is to call with no arguments which returns an object
equivalent to 0000-01-01 00:00:00.

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

Why have a "safe" way and a "dangerous" way? Because the whole point of this
module is to save typing.

        my $datetime = DateTime->quickie($arg);

Is less typing than

        my $datetime = DateTimeX::Quickie->new('DateTime' => $arg);

# EXPORTING

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
directly or using the more semantic export\_to class method.

        require DateTimeX::Quickie;
        DateTimeX::Quickie->import(export_to => 'My::DateTime::Class');
        DateTimeX::Quickie->export_to('Another::DateTime::Class');

This module does NOT export anything to the caller's namespace!

        use DateTimeX::Quickie qw(quickie); # error

        package My::Module;
        use DateTimeX::Quickie;
        quickie(...) # error

# PUBLIC METHODS

- quickie(list) OR quickie(arrayref)

    A list is interpreted as containing elements necessary to create a DateTime in 
    descending order, in other words, year, month, day, hour, minute, second,
    and optional nanosecond, in that order.

    Optionally, a time\_zone name may be supplied at the beginning or end of the list.
    This string will be checked using the DateTime::TimeZone->is\_valid\_name method.

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

- quickie(number)

    An integer or float is interpreted as an epoch time and is passed directly
    to DateTime's from\_epoch() class method.

- quickie(string)

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

    The returned DateTime will have its time\_zone set to the floating timezone, or
    offset-only timezone, as appropriate.

    The internal parser cannot handle unusual cases, such as dates before year 0000
    or after year 9999, for example.

    If unsuccessful, the module DateTime::Format::ISO8601 is used (if available)
    to attempt to parse it instead.

# DEBUGGING

The following package globals may assist in debugging.

- $DateTimeX::Quickie::looks\_like

    What this module thinks the most recent argument type was. Contains one of the
    strings 'empty', 'list', 'arrayref', 'epoch', or 'iso\_string'. May be undef.

- $DateTimeX::Quickie::parser\_used

    If used to parse an ISO-style string, may be 'internal' or 'external', with
    'external' referring to DateTime::Format::ISO8601;

# DEPENDENCIES

- perl v5.36 or greater

    This is primarily for native subroutine signatures. 

- Regexp::Common
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
