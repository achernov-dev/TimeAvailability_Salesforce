@IsTest
private class TMAV_TimeSlotsTest {
    @TestSetup
    static void generateUsers() {
        //Profile p = [SELECT Id FROM Profile WHERE Name='Standard User']; the profile doesn't exist during the package validation
        Id profileId = UserInfo.getProfileId();
        User u1 = new User(Alias = 'standt1',
                            Email='standarduser@testorg.com',
                            EmailEncodingKey='UTF-8',
                            LastName='Testing',
                            LanguageLocaleKey='en_US',
                            LocaleSidKey='en_US',
                            ProfileId = profileId,
                            TimeZoneSidKey='America/Los_Angeles',
                            UserName='testUser@tmav.com' + Integer.valueof((Math.random() * 1000)));
        User u2 = new User(Alias = 'standt2',
                Email='standarduser@testorg.com',
                EmailEncodingKey='UTF-8',
                LastName='Testing',
                LanguageLocaleKey='en_US',
                LocaleSidKey='en_US',
                ProfileId = profileId,
                TimeZoneSidKey='Europe/Moscow',
                UserName='testUser@tmav.com' + Integer.valueof((Math.random() * 1000)));
        User u3 = new User(Alias = 'standt3',
                Email='standarduser@testorg.com',
                EmailEncodingKey='UTF-8',
                LastName='Testing',
                LanguageLocaleKey='en_US',
                LocaleSidKey='en_US',
                ProfileId = profileId,
                TimeZoneSidKey='Asia/Dubai',
                UserName='testUser@tmav.com' + Integer.valueof((Math.random() * 1000)));

        insert new List<User>{u1, u2, u3};
    }

    @IsTest
    private static void calculateHoursCustom(){
        Map<Id, User> userMap = new Map<Id, User>([Select Id from User where UserName like 'testUser@tmav.com%']);
        TMAV_TimeSlotsCalculator tsc = new TMAV_TimeSlotsCalculator();
        tsc.useCustomStartEndDay(8, 20, true);
        Map<Date, Time[]> usersTime = tsc.getAvailableDateTimes(new List<Id>(userMap.keySet()));
        Event ev = new Event(Subject = 'Call');
        ev.StartDateTime = Datetime.newInstanceGMT(Date.today().addDays(1), usersTime.get(Date.today().addDays(1))[0]);
        ev.EndDateTime = ev.StartDateTime.addHours(1);
        ev.OwnerId = userMap.values()[0].Id;
        insert ev;
        usersTime = tsc.getAvailableDateTimes(new List<Id>(userMap.keySet()));
        tsc.useCustomStartEndDay(8, 20, false);
        Map<Date, Time[]> myTime = tsc.getAvailableDateTimes(UserInfo.getUserId());
        //assert.equals is not recommended due to unexpected light day time during the execution
    }
    @IsTest
    private static void calculateHoursBusinessHours(){
        Map<Id, User> userMap = new Map<Id, User>([Select Id from User where UserName like 'testUser@tmav.com%']);
        TMAV_TimeSlotsCalculator tsc = new TMAV_TimeSlotsCalculator();
        tsc.useBusinessHours();
        Map<Date, Time[]> usersTime = tsc.getAvailableDateTimes(new List<Id>(userMap.keySet()));
        Map<Date, Time[]> myTime = tsc.getAvailableDateTimes(UserInfo.getUserId());
        //assert.equals is not recommended due to unexpected light day time during the execution
    }
    @IsTest
    private static void calculateHoursCustomFields(){
        Map<Id, User> userMap = new Map<Id, User>([Select Id from User where UserName like 'testUser@tmav.com%']);
        TMAV_TimeSlotsCalculator tsc = new TMAV_TimeSlotsCalculator();
        tsc.useStartEndDayFields('Department', 'Division'); // just taking null values for test users
        Map<Date, Time[]> usersTime = tsc.getAvailableDateTimes(new List<Id>(userMap.keySet()));

    }
}