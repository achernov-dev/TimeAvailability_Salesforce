public with sharing class TMAV_TimeSlotsCalculator {
    final static Integer defaultDateRange = 14;
    final static Integer defaultSlotSize = 15;

    private Integer dateRange;
    private Integer slotSize;

    private Boolean usingBusinessHours;

    private Boolean usingStartEndDayFields;
    private String startDayField;
    private String endDayField;

    private Boolean usingCustomStartEndDay;
    private Integer customStartDay;
    private Integer customEndDay;
    private Boolean countTimeZonePerUser;

    private Date startDate;


    public TMAV_TimeSlotsCalculator(){
        this.slotSize = defaultSlotSize; //default
        this.dateRange = defaultDateRange; //default
        this.usingBusinessHours = false;
        this.usingStartEndDayFields = false;
        this.usingCustomStartEndDay = false;
        this.startDate = Date.today();
    }

    public void setSlotSize(Integer slotSize){
        this.slotSize = slotSize != null && slotSize > 0 ? slotSize : defaultSlotSize;
    }
    public void setDateRange(Integer daysOffset){
        this.dateRange = daysOffset != null && daysOffset > 0 ? daysOffset : defaultSlotSize;
    }
    public void setStartDate(Date dt){
        this.startDate = dt;
    }
    public void useBusinessHours(){
        this.usingBusinessHours = true;
        this.usingStartEndDayFields = false;
        this.usingCustomStartEndDay = false;
    }
    public void useStartEndDayFields(String startDayField, String endDayField){
        this.usingBusinessHours = false;
        this.usingStartEndDayFields = true;
        this.usingCustomStartEndDay = false;
        this.startDayField = startDayField;
        this.endDayField = endDayField;
    }
    public void useCustomStartEndDay(Integer startDay, Integer endDay, Boolean countTimeZonePerUser){
        this.usingBusinessHours = false;
        this.usingStartEndDayFields = false;
        this.usingCustomStartEndDay = true;
        this.customStartDay = startDay;
        this.customEndDay = endDay;
        this.countTimeZonePerUser = countTimeZonePerUser;
    }

    public Map<Date, Time[]> getAvailableDateTimes(Id userId){
        List<Id> generalInput = new List<Id>{ userId };
        return getAvailableDateTimes(generalInput);
    }

    public Map<Date, Time[]> getAvailableDateTimes(List<Id> userGroup){
        Map<String, List<Id>> generalInput = new Map<String, List<Id>>{'tempKey' => userGroup};
        Map<Date, Time[]> result = getAvailableDateTimes(generalInput).get('tempKey');
        return result;
    }

    public Map<String, Map<Date, Time[]>> getAvailableDateTimes(Map<String, List<Id>> userGroupMap){
        Map<Id, String[]> regroupedUserMap = TMAV_TimeSlotsHelper.regroupUsers(userGroupMap);
        List<Date> dates = TMAV_TimeSlotsHelper.getListOfDates(this.dateRange, this.startDate);
        Map<String, List<Event>> userEvents = TMAV_TimeSlotsHelper.queryUserEvents(dates, regroupedUserMap);
        Object groupBusnDay = this.usingBusinessHours ? TMAV_TimeSlotsHelper.getDayByBusinessHours(userGroupMap) :
                                        this.usingCustomStartEndDay ? TMAV_TimeSlotsHelper.getDayByCustomHours(this.customStartDay, this.customEndDay, this.countTimeZonePerUser, regroupedUserMap) :
                                        this.usingStartEndDayFields ? TMAV_TimeSlotsHelper.getDayByFields(userGroupMap, this.startDayField, this.endDayField) :
                                        null;
        Set<String> allGroups = userGroupMap.keySet();
        Map<String, Map<Date, Time[]>> result = TMAV_TimeSlotsHelper.calculateTimeSlots(allGroups, dates, userEvents, groupBusnDay, slotSize);
        return result;
    }

}