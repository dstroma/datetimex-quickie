#include <stdio.h>
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
	bool  error;
	char  error_msg[];
};

/*
struct DateTimeAndOffsetStruct {
	char datetime[37];
	bool has_offset;
	char offset[7];
};
*/

/*
struct DateTimeAndOffsetStruct split_datetime_and_offset (char dstring[60]) {
	struct DateTimeAndOffsetStruct returnVal;
	char offset[7];
	int startOfOffset = -1;

	returnVal.has_offset = false;

	// Copy datetime string and look for offset starting with + or - 
	for (int i = 0; i <= 36; i++) {
		if (dstring[i] == '+' || dstring[i] == '-') {
			startOfOffset = i;
			returnVal.datetime[i] = '\0';
			i = 100;
		} else {
			returnVal.datetime[i] = dstring[i];
		}
	}

	// Copy offset 
	if (startOfOffset > 0) {
		returnVal.has_offset = true;
		for (int i = 0; i <= 6; i++) {
			returnVal.offset[i] = dstring[i + startOfOffset];
			if (dstring[i + startOfOffset] == '\0') {
				i = 100;
			}
		}
	}

	returnVal.offset[6] = '\0'; // just in case 

	return returnVal;
}
*/

bool is_digit (char c) {
	if (c == '0' || c == '1' || c == '2' || c == '3' || c == '4' || c == '5' || c == '6' || c == '7' || c == '8' || c == '9') {
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
			dstruct->is_utc = true;

			/* We are done, there can't be anything after Z */
			return true;
		}

		/* Offset */
		if (dstring[indexOfLastDigit + 1] == '+' || dstring[indexOfLastDigit + 1] == '-') {
			char offset_direction = dstring[indexOfLastDigit + 1];
			printf("DEBUG: Found offset %c\n", offset_direction);
			int i = indexOfLastDigit + 2;

			/* Hour only (single digit) */
			if (is_digit(dstring[i]) && dstring[i + 1] == '\0') {
				printf("DEBUG: One digit hour\n");
				int offset_hours = dstring[i] - '0';
				dstruct->offset = offset_hours * 3600;
				return true;
			}

			/* Hours, maybe minutes */
			else if (is_digit(dstring[i]) && is_digit(dstring[i + 1])) {
				printf("DEBUG: Two digit hour\n");

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
					printf("DEBUG: Looking for minutes, the minute characters are %c%c\n", dstring[i], dstring[i+1]); 
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

/*
bool check_digits (char dtstring[19]) {
	printf("in function check_digits ~ %c %c %c %c ~\n", dtstring[0], dtstring[1], dtstring[2], dtstring[3]);
	int positionsOfDigits[14] = {0, 1, 2, 3, 5, 6, 8, 9, 11, 12, 14, 15, 17, 18};
	for (int i = 0; i < 14; i++) {
		//printf("Iteration: %d\n", i);
		//printf("Checking digit: %d\n", positionsOfDigits[i]);
		if (!is_digit(dtstring[positionsOfDigits[i]])) {
			return false;
		}
	}
	return true;
}
*/



int main () {
	struct DateStruct result_datetime;
	bool success;
	/*                                      1000000000 */
	char dateStr[37] = "2020-02-03T08:30:03.14152987647-0230";

/*
	struct DateTimeAndOffsetStruct datetime_and_offset;
	datetime_and_offset = split_datetime_and_offset(dateStr);
	printf("\n");
	printf("The datetime and offset has been split:\n");
	printf("  DateTime string: %s\n", datetime_and_offset.datetime);
*/

	success = parse_date(dateStr, &result_datetime);
	if (success) {
		printf("\n\n");
		printf("The year   is %i\n", result_datetime.year);
		printf("The month  is %i\n", result_datetime.month);
		printf("The day    is %i\n", result_datetime.day);
		printf("The hour   is %i\n", result_datetime.hour);
		printf("The minute is %i\n", result_datetime.minute);
		printf("The second is %i\n", result_datetime.second);
		printf("The ns     is %li\n", result_datetime.nanosecond);
		printf("The offset is %i\n", result_datetime.offset);
		if (result_datetime.is_utc) {
			printf("The timezone is UTC.\n");
		} else {
			printf("No timezone specified.\n");
		}
	} else {
		printf("\n\nFAILED.\n\n");
	}

	return 0;
}

