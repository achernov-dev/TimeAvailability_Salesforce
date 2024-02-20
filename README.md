# Time Availability For Users
The current module allows using generic functions to calculate time capacity for every user(s) in the org counting it by start/end of business day and busied activities such as events.

## Generic functions to calculate time availability
The module is using functions returning Map<Date, Time[]> variable that contains available dates and list of time slots for every date in GMT format. The algorithm of calculation is counting timezone for every user and also can optionally count start and end of business day for every user.
To check availability for every time slot, system is checking all existed events for requested users. So timeslots that are busy by some events will not be returned.
###Get time slots for users with default parameters
```apex
List<Id> userIds = <...>; //list of user Ids we need to calculate available time slots. For example, participants of visit we want to schedule.
TMAV_TimeSlotsCalculator tsc = new TMAV_TimeSlotsCalculator();
Map<Date, Time[]> usersTime = tsc.getAvailableDateTimes(userIds);
```

This type is not counting start/end of business day and returns 15-minutes time slots for every date for 2 weeks from today.

###Assigning additional parameters
```apex
List<Id> userIds = <...>; //list of user Ids we need to calculate available time slots. For example, participants of visit we want to schedule.
TMAV_TimeSlotsCalculator tsc = new TMAV_TimeSlotsCalculator();
tsc.setSlotSize(20) //amount of minutes for time slots. Default is 15. With value 20 output will be like: [00:00, 00:20, 00:40, 01:00, 01:20...etc]
tsc.setDateRange(21) // amount of dates we need to check and return available timeslots. Default is 14 (two weeks)
tsc.setStartDate(myDate); //set a date from which we want to calculate time slots. Default is today.
Map<Date, Time[]> usersTime = tsc.getAvailableDateTimes(userIds);
```
## Using Start/End of business day.
The module allows counting 3 types of defining "Start/End of business day". Only one can be used.
### 1. Using custom input.
```apex
TMAV_TimeSlotsCalculator tsc = new TMAV_TimeSlotsCalculator();
tsc.useCustomStartEndDay(Integer startDay, Integer endDay, Boolean countTimeZonePerUser); // this method set up "custom" mode and allows using Integer variable to define start/end of day.
```
startDay - start of day

endDay - end of day

countTimeZonePerUser - if set to true, startDay and endDay integers will be accumulated counting time zone for every user in the group. If false - only time zone of current context user will be counted.

### 2. Using custom fields.
```apex
TMAV_TimeSlotsCalculator tsc = new TMAV_TimeSlotsCalculator();
tsc.useStartEndDayFields(String startDayField, String endDayField);
```
The same option as custom input but here you can use custom fields on User object that are defining start and end day of business day.

startDayField - API name of field with Start hour on User object

endDayField - API name of field with End hour on User object


### 3. Business Hours
```apex
TMAV_TimeSlotsCalculator tsc = new TMAV_TimeSlotsCalculator();
tsc.useBusinessHours();
```
No inputs needed for this mode. The module is using BusinessHours object to get available time slots. The algorithm will map timezones of user group to appropriate BusinessHours record or use default BusinessHours if not found.

## Types of running
```apex
Map<Date, Time[]> getAvailableDateTimes(Id userId) // calculates time slots for one user only
Map<Date, Time[]> getAvailableDateTimes(List<Id> userGroup){ //calculates time slots for one group of users
Map<String, Map<Date, Time[]>> getAvailableDateTimes(Map<String, List<Id>> userGroupMap) //calculates time slots for multiple groups. The key of input map should contain some identificator of the group(ex. visit id or random string). The same key will be returned in the output map.

```

