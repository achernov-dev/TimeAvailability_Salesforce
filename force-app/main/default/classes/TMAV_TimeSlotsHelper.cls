public without sharing class TMAV_TimeSlotsHelper {

    final static List<String> WEEK_DAYS = new List<String>{'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'};

    public static List<Date> getListOfDates(Integer dateRange, Date startDate){
        List<Date> result = new List<Date>();
        for(Integer i = 0; i < dateRange; i++){
            result.add(startDate.addDays(i));
        }
        return result;
    }
    public static Map<String, List<Event>> queryUserEvents(List<Date> dates, Map<Id, String[]> regroupedUserMap){
        Map<String, List<Event>> result = new Map<String, List<Event>>();
        Date minDate = dates.get(0);
        Date maxDate = dates.get(dates.size() - 1);
        for(Event ev : [SELECT Id, OwnerId, StartDateTime, EndDateTime, IsAllDayEvent FROM Event
                                                                                        WHERE OwnerId in: regroupedUserMap.keySet()
                                                                                        AND StartDateTime <=: maxDate
                                                                                        AND EndDateTime >=: minDate
                                                                                        ORDER BY StartDateTime ASC]){

            String[] userGroups = regroupedUserMap.get(ev.OwnerId);
            for(String userGroup : userGroups){
                if(!result.containsKey(userGroup)){
                    result.put(userGroup, new List<Event>());
                }
                result.get(userGroup).add(ev);
            }
        }
        return result;
    }


    public static Map<Id, String[]> regroupUsers(Map<String, List<Id>> userGroupMap){
        Map<Id, String[]> result = new Map<Id, String[]>();
        for(String groupKey : userGroupMap.keySet()){
            for(Id userId : userGroupMap.get(groupKey)){
                if(!result.containsKey(userId)){
                    result.put(userId, new List<String>());
                }
                result.get(userId).add(groupKey);
            }
        }
        return result;
    }

    public static Map<String, Object> getDayByBusinessHours(Map<String, List<Id>> userGroups) {
        Map<String, Map<String, BusinessDay>> result = new Map<String, Map<String, BusinessDay>>();
        List<BusinessHours> businessHours = new List<BusinessHours>([
                SELECT  IsDefault, TimeZoneSidKey, MondayEndTime, MondayStartTime, TuesdayEndTime, TuesdayStartTime,
                        WednesdayEndTime, WednesdayStartTime, ThursdayEndTime, ThursdayStartTime,
                        FridayEndTime, FridayStartTime, SaturdayEndTime, SaturdayStartTime, SundayEndTime, SundayStartTime
                FROM BusinessHours
                WHERE IsActive = TRUE]);
        String defaultTimeZoneSidKey;
        Map<String, Map<String, BusinessDay>> weekDayBusinessHoursMap = new Map<String, Map<String, TMAV_TimeSlotsHelper.BusinessDay>>();
        for (BusinessHours bh : businessHours) {
            weekDayBusinessHoursMap.put(bh.TimeZoneSidKey, generateWeekMapByBusinessHours(bh));
            if (bh.IsDefault) {
                defaultTimeZoneSidKey = bh.TimeZoneSidKey;
            }
        }
        Set<Id> userIds = new Set<Id>();
        for (String groupKey : userGroups.keySet()) {
            if (userGroups.get(groupKey) != null) {
                userIds.addAll(userGroups.get(groupKey));
            }
        }
        Map<Id, User> userList = new Map<Id, User>([SELECT TimeZoneSidKey FROM User WHERE Id IN : userIds]);
        for (String groupKey : userGroups.keySet()) {
            if (userGroups.get(groupKey).isEmpty()) continue;
            String tz = defaultTimeZoneSidKey;
            if (weekDayBusinessHoursMap.containsKey(userList.get(userGroups.get(groupKey)[0]).TimeZoneSidKey)) {
                tz = userList.get(userGroups.get(groupKey)[0]).TimeZoneSidKey;
            }
            result.put(groupKey, new Map<String, BusinessDay>());
            for (String weekDay : WEEK_DAYS) {
                BusinessDay groupDay = new BusinessDay();
                groupDay.fillHoursSet(0, 24, tz);
                for (Id userId : userGroups.get(groupKey)) {
                    User us = userList.get(userId);
                    BusinessDay userDay = new BusinessDay();
                    if (weekDayBusinessHoursMap.containsKey(us.TimeZoneSidKey)) {
                        userDay = weekDayBusinessHoursMap.get(us.TimeZoneSidKey).get(weekDay);
                    } else {
                        userDay = weekDayBusinessHoursMap.get(defaultTimeZoneSidKey).get(weekDay);
                    }
                    groupDay.mergeBusDay(userDay);
                }
                result.get(groupKey).put(weekDay, groupDay);
            }
        }
        return result;
    }
    public static Object getDayByCustomHours(Integer startDay, Integer endDay, Boolean countTZPerUser, Map<Id, String[]> regroupedUserMap){
        Map<String, BusinessDay> result = new Map<String, BusinessDay>();
        if(!countTZPerUser){
            BusinessDay originalBd = new BusinessDay();
            originalBd.fillHoursSet(startDay, endDay, UserInfo.getTimeZone().getId());
            return originalBd;
        }
        else{
            for(User u : [SELECT Id, TimeZoneSidKey from User where Id in: regroupedUserMap.keySet()]){
                BusinessDay bDay = new BusinessDay();
                bDay.fillHoursSet(startDay, endDay, u.TimeZoneSidKey);
                for(String groupKey : regroupedUserMap.get(u.Id)){
                    if(!result.containsKey(groupKey)){
                        result.put(groupKey, bDay);
                    }
                    else{
                        result.get(groupKey).mergeBusDay(bDay);
                    }
                }
            }
        }

        return result;
    }

    public static Map<String, Object> getDayByFields(Map<String, List<Id>> userGroups, String startOfDayField, String endOfDayField){
        Map<String, BusinessDay> result = new Map<String, BusinessDay>();
        Set<Id> userIds = new Set<Id>();
        for (String userGroup : userGroups.keySet()) {
            userIds.addAll(userGroups.get(userGroup));
        }
        String query = 'SELECT ' + startOfDayField + ', ' + endOfDayField + ', TimeZoneSidKey FROM User WHERE Id IN : userIds';
        Map<Id, User> userMap = new Map<Id, User>((List<User>) Database.query(query));
        for (String userGroup : userGroups.keySet()) {
            BusinessDay groupDay = new BusinessDay();
            for (Id userId : userGroups.get(userGroup)) {
                User us = userMap.get(userId);
                BusinessDay userDay = new BusinessDay();
                if (groupDay.availableHours.isEmpty()) {
                    groupDay.fillHoursSet(0, 24, us.TimeZoneSidKey);
                }
                Integer startDayValue = getStartEndValue(us.get(startOfDayField));
                Integer endDayValue = getStartEndValue(us.get(endOfDayField));
                userDay.fillHoursSet(startDayValue, endDayValue, us.TimeZoneSidKey);
                groupDay.mergeBusDay(userDay);
                if (groupDay.availableHours.isEmpty()) {
                    break;
                }
            }
            result.put(userGroup, groupDay);
        }
        return result;
    }
    private static Integer getStartEndValue(Object dayValueObj) {
        if (dayValueObj == null) return 0;
        Integer dayValue = Integer.valueOf(dayValueObj);
        if (dayValue < 0 || dayValue > 24) {
            return 0;
        } else {
            return dayValue;
        }
    }
    public static Map<String, Map<Date, Time[]>> calculateTimeSlots(Set<String> allGroups, List<Date> dates, Map<String, List<Event>> userEvents, Object busDayMap, Integer slotSize){
        Map<String, Map<Date, List<Time>>>  groupSlotsMap = getSlotsWithoutEvents(allGroups, dates, busDayMap, slotSize);
        Date minDate = dates.get(0);
        Date maxDate = dates.get(dates.size() - 1);
        for(String groupKey : allGroups){
            List<Event> groupEvents = userEvents.get(groupKey);

            if(groupEvents != null){
                Map<Date, List<Time>> slotsMap = groupSlotsMap.get(groupKey);
                for(Event ev : groupEvents){
                    Date startDate = ev.StartDateTime.dateGMT();
                    Date endDate = ev.EndDateTime.dateGMT();
                    if(endDate > startDate || ev.isAllDayEvent){
                        Date dateCounter = ev.isAllDayEvent ? startDate : startDate.addDays(1);
                        while(dateCounter <= maxDate && (dateCounter < endDate || (dateCounter <= endDate && ev.isAllDayEvent))){
                            if(slotsMap.containsKey(dateCounter)){
                                slotsMap.put(dateCounter, new List<Time>());
                            }
                            dateCounter = dateCounter.addDays(1);
                        }
                    }
                    if(!ev.isAllDayEvent){
                        Time startTime = endDate == startDate ? ev.StartDateTime.timeGMT() : Time.newInstance(0,0,0, 0);
                        Time endTime = endDate == startDate ? ev.EndDateTime.timeGMT() : Time.newInstance(23,59,59, 0);
                        Set<Time> timeSetStart = new Set<Time>(slotsMap.get(startDate));
                        for(Time tm : slotsMap.get(startDate)){
                            if(tm >= startTime && tm < endTime){
                                timeSetStart.remove(tm);
                            }
                        }
                        slotsMap.put(startDate, new List<Time>(timeSetStart));
                        if(endDate > startDate){
                            Set<Time> timeSetEnd = new Set<Time>(slotsMap.get(endDate));
                            for(Time tm : slotsMap.get(endDate)){
                                if(tm >= startTime && tm < endTime){
                                    timeSetEnd.remove(tm);
                                }
                            }
                            slotsMap.put(endDate, new List<Time>(timeSetEnd));
                        }
                    }

                }
                groupSlotsMap.put(groupKey, slotsMap);
            }
        }


        return groupSlotsMap;
    }

    public static Map<String, Map<Date, List<Time>>> getSlotsWithoutEvents(Set<String> allGroups, List<Date> dates, Object busDayMap, Integer slotSize){
        Map<String, Map<Date, List<Time>>> result = new Map<String, Map<Date, List<Time>>>();
        String busDayType = busDayMap == null || busDayMap instanceof BusinessDay ? 'oneDay' :
                busDayMap instanceof Map<String, Map<String, BusinessDay>> ? 'weeklyHours' :
                        busDayMap instanceof Map<String, BusinessDay> ? 'dailyHours' :
                                null;
        if(busDayType == 'oneDay'){
            result = setupAllSlots(allGroups, dates, slotSize, busDayMap);
        }
        if(busDayType == 'dailyHours'){
            result = setupSlotsByGroup(allGroups, dates, slotSize, busDayMap);
        }
        if(busDayType == 'weeklyHours'){
            result = setupSlotsByWeekDay(allGroups, dates, slotSize, busDayMap);
        }
        removeTodaySlots(result);
        return result;
    }
    private static void removeTodaySlots(Map<String, Map<Date, List<Time>>> groupMap){
        Set<Time> timeSet;
        for(Map<Date, List<Time>> dateMap : groupMap.values()){
            if(dateMap.containsKey(Date.today())){
                if(timeSet == null) {
                    Time nowTime = Datetime.now().time();
                    timeSet = new Set<Time>(dateMap.get(Date.today()));
                    for (Time slot : dateMap.get(Date.today())) {
                        if (slot <= nowTime) {
                            timeSet.remove(slot);
                        }
                    }
                }
                dateMap.put(Date.today(), new List<Time>(timeSet));
            }
        }
    }
    public static Map<String, Map<Date, List<Time>>> setupSlotsByWeekDay(Set<String> allGroups, List<Date> dates, Integer slotSize, Object busDay){
        Map<String, Map<Date, List<Time>>> result = new Map<String, Map<Date, List<Time>>>();
        Map<String, Map<String, BusinessDay>> busDayMap = (Map<String, Map<String, BusinessDay>>) busDay;

        Map<Date, String> dateWeekdayMap = initWeekdaysForDates(dates);
        for(String groupKey : allGroups){
            result.put(groupKey, new Map<Date, List<Time>>());
            for(Date dt : dates){
                String weekDay = dateWeekdayMap.get(dt);
                if(busDayMap.containsKey(groupKey) && busDayMap.get(groupKey).containsKey(weekDay)){
                    BusinessDay bd = busDayMap.get(groupKey).get(weekDay);
                    List<Time> timeList = generateSet(bd, slotSize);
                    result.get(groupKey).put(dt, timeList);
                }
            }
        }
        return result;

    }
    public static Map<Date, String> initWeekdaysForDates(List<Date> dates){
        Map<Date, String> result = new Map<Date, String>();
        Time timeMock = Time.newInstance(0, 0, 0, 0);
        for(Date dt : dates){
            String weekDay = DateTime.newInstance(dt, timeMock).formatGMT('EEEE');
            result.put(dt, weekDay);
        }
        return result;
    }
    public static Map<String, Map<Date, List<Time>>> setupSlotsByGroup(Set<String> allGroups, List<Date> dates, Integer slotSize, Object busDay){
        Map<String, Map<Date, List<Time>>> result = new Map<String, Map<Date, List<Time>>>();
        Map<String, BusinessDay> busDayMap = (Map<String, BusinessDay>) busDay;
        for(String groupKey : allGroups){
            result.put(groupKey, new Map<Date, List<Time>>());
            List<Time> timeList = generateSet(busDayMap.get(groupKey), slotSize);
            for(Date d : dates){
                result.get(groupKey).put(d, timeList);
            }
        }
        return result;

    }
    public static Map<String, Map<Date, List<Time>>> setupAllSlots(Set<String> allGroups, List<Date> dates, Integer slotSize, Object busDay){
        Map<String, Map<Date, List<Time>>> result = new Map<String, Map<Date, List<Time>>>();
        BusinessDay bd;
        if(busDay != null && busDay instanceof BusinessDay){
            bd = (BusinessDay) busDay;
        }
        else{
            bd = new BusinessDay();
            bd.fillHoursSet(0, 24, 'GMT');
        }

        List<Time> timeList = generateSet(bd, slotSize);
        Map<Date, List<Time>> dateMap = new Map<Date, List<Time>>();
        for(Date d : dates){
            dateMap.put(d, timeList);
        }
        for(String groupKey : allGroups){
            result.put(groupKey, dateMap);
        }
        return result;
    }
    public static List<Time> generateSet(BusinessDay bd, Integer slot){
        List<Integer> hoursList = new List<Integer>(bd.availableHours);
        Set<Time> resultSet = new Set<Time>();
        hoursList.sort();
        Time lastTime;
        for(Integer hour : hoursList){
            if(lastTime == null || (lastTime != null && lastTime.hour() != hour)){
                lastTime = Time.newInstance(hour, 0, 0, 0);
            }
            while(lastTime.hour() == hour && slot != 0){
                resultSet.add(lastTime);
                lastTime = lastTime.addMinutes(slot);
            }
        }
        List<Time> timeList = new List<Time>(resultSet);
        timeList.sort();
        return timeList;
    }

    public static Map<String, BusinessDay> generateWeekMapByBusinessHours(BusinessHours bh){
        Map<String, BusinessDay> result = new Map<String, BusinessDay>();
        for(String weekDay : WEEK_DAYS){
            BusinessDay bd = new BusinessDay(bh, weekDay);
            result.put(weekDay, bd);
        }
        for(String weekDay : result.keySet()){
            BusinessDay bd = result.get(weekDay);
            if(!bd.hoursToMove.isEmpty() && bd.dayMove != 0){
                Integer weekDayIndex = WEEK_DAYS.indexOf(weekDay) + bd.dayMove;
                weekDayIndex = weekDayIndex == WEEK_DAYS.size() ? 0 : weekDayIndex == -1 ? WEEK_DAYS.size() - 1 : weekDayIndex;
                result.get(WEEK_DAYS[weekDayIndex]).availableHours.addAll(bd.hoursToMove);
                bd.hoursToMove = null;
            }
        }
        return result;
    }

    public class BusinessDay{
        Set<Integer> availableHours;

        Integer dayMove;
        Set<Integer> hoursToMove;
        Boolean forceDayMove;
        public BusinessDay(){
            this.availableHours = new Set<Integer>();
        }

        public BusinessDay(BusinessHours bh, String weekDay){
            this.availableHours = new Set<Integer>();
            this.hoursToMove = new Set<Integer>();
            Time startTime = (Time) bh.get(weekDay + 'StartTime');
            Time endTime = (Time) bh.get(weekDay + 'EndTime');
            if(startTime != null && endTime != null) {
                Integer offset = TimeZone.getTimeZone(bh.TimeZoneSidKey).getOffset(Date.today());
                Boolean isFullDay = startTime == endTime ? true : false;
                Integer startHour = isFullDay ? startTime.hour() : getRoundHour(startTime, offset, true); //round
                Integer endHour = isFullDay ? endTime.hour() : getRoundHour(endTime, offset, false); //round
                this.dayMove = offset > 0 ? -1 : offset < 0 ? 1 : 0;
                if (startHour != endHour || isFullDay && startHour == endHour) {
                    this.fillHoursSet(startHour, endHour, bh.TimeZoneSidKey);
                }
            }
        }

        public Integer getRoundHour(Time dayTime, Integer offset, Boolean isStartDay) {
            Integer roundHour = dayTime.hour();
            Integer sign = offset < 0 ? -1 : 1;
            Integer offsetMinutes = sign * offset/1000/60;
            Integer fullHours = offsetMinutes/60;
            Integer offsetHour = dayTime.minute() + offsetMinutes - fullHours * 60;
            if (isStartDay) {
                if (dayTime.minute() > 0) {
                    roundHour++;
                }
                if (offsetHour > 60) {
                    roundHour++;
                }
                if(roundHour < dayTime.hour()){
                    this.forceDayMove = true;
                }
            } else if (offsetHour >= 60) {
                roundHour++;
            }
            return roundHour;
        }

        public void fillHoursSet(Integer startDay, Integer endDay, String tzKey){
            TimeZone tz = Timezone.getTimeZone(tzKey);
            Integer sdGMT = gmtInteger(startDay, tz);
            Integer edGMT = gmtInteger(endDay, tz);
            if(sdGMT > edGMT){
                for(Integer i = sdGMT; i < 24; i ++){
                    if(this.dayMove == -1){
                        hoursToMove.add(i);
                    }
                    else{
                        availableHours.add(i);
                    }
                }
                for(Integer i = 0; i < edGMT; i++){
                    if(this.dayMove == 1){
                        hoursToMove.add(i);
                    }
                    else{
                        availableHours.add(i);
                    }
                }
            }
            else if(sdGMT < edGMT){
                for(Integer i = sdGMT; i < edGMT; i ++){
                    if(forceDayMove == true){
                        hoursToMove.add(i);
                    }
                    else{
                        availableHours.add(i);
                    }
                }
            }
            else if(sdGMT == edGmt){
                for(Integer i = 0; i < 24; i ++){
                    availableHours.add(i);
                }
            }
        }

        public Integer gmtInteger(Integer hour, TimeZone tz){
            Integer offset = -1 * tz.getOffset(Date.today());
            return Time.newInstance(hour, 0, 0, 0).addMilliseconds(offset).hour();
        }

        public void mergeBusDay(BusinessDay mergeBd){
            this.availableHours.retainAll(mergeBd.availableHours);
        }
    }
}