package DateTimeX::Create::ParseWithC 0.001;

use v5.36;
use Inline C => <<'END_OF_C_CODE';
 
#include <string.h>
#include <stdbool.h>
#include <stdlib.h>

struct DateStruct {
	short year;
	short month;
	short day;
	short hour;
	short minute;
	short second;
	long  nanosecond;
	bool  is_utc;
	int   offset;
};


bool is_digit (char c) {
	if (c >= '0' && c <= '9') {
		return true;
	} else {
		return false;
	}
}

bool parse_date (char dstring[37], struct DateStruct *dstruct) {
	char frac_seconds[11] = "0.000000000";
	char nanoseconds[8];

	double dbl_nano;
	double dbl_fsec;

	if (
		is_digit(dstring[0]) &&
		is_digit(dstring[1]) &&
		is_digit(dstring[2]) &&
		is_digit(dstring[3]) &&
		dstring[4] == '-' &&
		is_digit(dstring[5]) &&
		is_digit(dstring[6]) &&
		dstring[7] == '-' &&
		is_digit(dstring[8]) &&
		is_digit(dstring[9]) &&
		(dstring[10] == ' ' || dstring[10] == 'T') &&
		is_digit(dstring[11]) &&	
		is_digit(dstring[12]) &&	
		dstring[13] == ':' &&
		is_digit(dstring[14]) &&	
		is_digit(dstring[15]) &&	
		dstring[16] == ':' &&
		is_digit(dstring[17]) && 
		is_digit(dstring[18])
	)
	{
		/* Set defaults */
		dstruct->is_utc = false;
		dstruct->offset = 0;
		dstruct->nanosecond = 0;

		/* Year */
		char year[5]    = {dstring[0], dstring[1], dstring[2], dstring[3], '\0'};
		dstruct->year   = atoi(year);

		/* Month */
		char month[3]   = {dstring[5], dstring[6], '\0'};
		dstruct->month  = atoi(month);

		/* Day */
		char day[3]     = {dstring[8], dstring[9], '\0'};
		dstruct->day    = atoi(day);

		/* Hour */
		char hour[3]    = {dstring[11], dstring[12], '\0'};
		dstruct->hour   = atoi(hour);

		/* Minute */
		char minute[3]  = {dstring[14], dstring[15], '\0'};
		dstruct->minute = atoi(minute);

		/* Second */
		char second[3]  = {dstring[17], dstring[18], '\0'};
		dstruct->second = atoi(second);

		/* Fractional seconds */
		int indexOfLastDigit = 18;
		if (dstring[19] == '.' || dstring[19] == ',') {
			if (is_digit(dstring[20])) {
				/* Digits after 10th digit (index 9) are irrelevant */
				int i = 0;
				while (i <= 9 && i >= 0) {
					if (is_digit(dstring[20 + i])) {
						indexOfLastDigit = 20 + i;
						if (i >= 9) {
							if (dstring[20 + i] >= '5') {
								frac_seconds[i + 2 - 1] = dstring[20 + i - 1] + 1;
							}
						} else {
							frac_seconds[i + 2] = dstring[20 + i];
						}
						i++;
					} else {
						/* We have run into a non-digit. Exit loop. */
						i = -1;
					}
				}

				/* There might be more digits */
				if (i > 0) {
					for (i = i; i <= 32; i++) {
						if (is_digit(dstring[20 + i])) {
							indexOfLastDigit = 20 + i;
						} else {
							i = 100;
						}
					}
				}

				dbl_fsec = atof(frac_seconds);
				dbl_nano = dbl_fsec * 1000000000;
				dstruct->nanosecond = (long)dbl_nano;
			}
			else
			{
				printf("Invalid date.");
				return false;
			}
		}

		/* Time zone */
		if (dstring[indexOfLastDigit + 1] == 'Z' || dstring[indexOfLastDigit + 1] == 'z') {
			dstruct->is_utc    = true;
			indexOfLastDigit++;
			/* above we cheat and advance 1 digit, this is to catch an invalid
			   string in which both Z and an offset are presented
			*/
		}

		/* Offset */
		if (dstring[indexOfLastDigit + 1] == '+' || dstring[indexOfLastDigit + 1] == '-') {
			if (dstruct->is_utc) {
				/* Cannot have both an offset and a timezone of Z */
				return false;
			}
			char offset_direction = dstring[indexOfLastDigit + 1];
			int i = indexOfLastDigit + 2;

			/* Hour only (single digit) */
			if (is_digit(dstring[i]) && dstring[i + 1] == '\0') {
				// printf("DEBUG: One digit hour\n");
				int offset_hours = dstring[i] - '0';
				dstruct->offset = offset_hours * 3600;
				return true;
			}

			/* Hours, maybe minutes */
			else if (is_digit(dstring[i]) && is_digit(dstring[i + 1])) {
				// printf("DEBUG: Two digit hour\n");

				/* Get hours */
				char offset_hours_str[3] = {dstring[i], dstring[i + 1], '\0'};
				int offset_hours = atoi(offset_hours_str);
				dstruct->offset = offset_hours * 3600;

				/* Look for minutes as well */
				i = i + 2;
				if (dstring[i] == ':') {
					i++;
				}
				if (is_digit(dstring[i]) && is_digit(dstring[i+1])) {
					char offset_minutes_str[3] = {dstring[i], dstring[i + 1], '\0'};
					int offset_minutes = atoi(offset_minutes_str);
					dstruct->offset = dstruct->offset + offset_minutes * 60;
				} else {
					// printf("DEBUG: Looking for minutes, the minute characters are %c%c\n", dstring[i], dstring[i+1]); 
				}
			}
			
			if (offset_direction == '-') {
				dstruct->offset = 0 - dstruct->offset;
			}
		}

		return true;
	}
	else
	{
		return false;
	}
}

void c_parse_datetime_string (char* input_date_string) {
	struct DateStruct result_datetime;
	bool success;
	char dateStr[37] = "2020-02-03T08:30:03.14152987647-0230";

	/* Copy input to dateStr */
	/*
	printf("The length of the input string is %i\n", strlen(input_date_string));
	printf("The input string is %s\n", input_date_string);
	if (input_date_string[35] == '\0') {
		printf("Found null terminator at index 35.\n");
	}
	if (input_date_string[37] == '\0') {
		printf("Found null terminator at index 37.\n");
	}
	*/

	success = parse_date(input_date_string, &result_datetime);
	if (success) {
		Inline_Stack_Vars;
		Inline_Stack_Reset;
		Inline_Stack_Push(sv_2mortal(newSViv(result_datetime.year)));
		Inline_Stack_Push(sv_2mortal(newSViv(result_datetime.month)));
		Inline_Stack_Push(sv_2mortal(newSViv(result_datetime.day)));
		Inline_Stack_Push(sv_2mortal(newSViv(result_datetime.hour)));
		Inline_Stack_Push(sv_2mortal(newSViv(result_datetime.minute)));
		Inline_Stack_Push(sv_2mortal(newSViv(result_datetime.second)));
		Inline_Stack_Push(sv_2mortal(newSViv(result_datetime.nanosecond)));
		Inline_Stack_Push(sv_2mortal(newSViv(result_datetime.is_utc)));
		if (result_datetime.offset) {
			Inline_Stack_Push(sv_2mortal(newSViv(result_datetime.offset)));
		}
		Inline_Stack_Done;
	}
}

END_OF_C_CODE

*parse = \&c_parse_datetime_string;

1;

__END__

use Benchmark qw/cmpthese/;
use DateTimeX::Create;

my $pure_perl = sub {
	my $dt = DateTimeX::Create::new_from_iso_string('DateTime' => '2020-02-03T07:30:03.14152987647-0230');
};
my $inline_c  = sub {
	my $dt = DateTimeX::Create::new_from_c('DateTime' => c_parse_datetime_string('2020-02-03T07:30:03.14152987647-0230'));
};

say "Test:";
say "	Pure Perl: " . $pure_perl->();
say "		Timezone: " . $pure_perl->()->time_zone;
say "		Offset  : " . $pure_perl->()->offset;
say "	Inline C:  " . $inline_c->();
say "		Timezone: " . $inline_c->()->time_zone;
say "		Offset  : " . $inline_c->()->offset;
say '';
sleep 2;
cmpthese(20_000, {
	pure_perl => $pure_perl,
	inline_c  => $inline_c,
});


