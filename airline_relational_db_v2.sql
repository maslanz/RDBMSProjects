create database airline_relational_db_v2
use airline_relational_db_v2

/*TABLES*/
create table FLIGHT (
	Flight_number varchar(8),
	Airline varchar(32) not null,
	Weekdays varchar(16),
	primary key(Flight_number)
)

create table AIRPORT (
	Airport_code varchar(3),
	Name varchar(32) not null,
	City varchar(16) not null,
	State varchar(16) not null,
	primary key(Airport_code)
)

create table AIRPLANE_TYPE (
	Airplane_type_name varchar(16),
	Max_seats int not null,
	Company varchar(16) not null,
	primary key(Airplane_type_name)
)

create table FARE (
	Flight_number varchar(8),
	Fare_code int,
	Amount int not null,
	Restrictions bit not null,
	Baggage_weight int not null --added later
	primary key(Flight_number, Fare_code),
	foreign key(Flight_number) references FLIGHT(Flight_number) on delete cascade on update cascade
)

create table AIRPLANE (
	Airplane_id int,
	Total_number_of_seats int not null,
	Airplane_type varchar(16) not null,
	primary key(Airplane_id),
	foreign key(Airplane_type) references AIRPLANE_TYPE(Airplane_type_name) on delete cascade on update cascade
)

create table CAN_LAND (
	Airplane_type_name varchar(16),
	Airport_code varchar(3),
	primary key(Airplane_type_name, Airport_code),
	foreign key(Airplane_type_name) references AIRPLANE_TYPE(Airplane_type_name) on delete cascade on update cascade,
	foreign key(Airport_code) references AIRPORT(Airport_code) on delete cascade on update cascade
)

create table FLIGHT_LEG (
	Flight_number varchar(8),
	Leg_number int,
	Departure_airport_code varchar(3) not null,
	Scheduled_departure_time datetime not null,
	Arrival_airport_code varchar(3) not null,
	Scheduled_arrival_time datetime not null,
	primary key(Flight_number, Leg_number),
	foreign key(Flight_number) references FLIGHT(Flight_number) on delete no action on update no action,
	foreign key(Departure_airport_code) references AIRPORT(Airport_code) on delete no action on update no action,
	foreign key(Arrival_airport_code) references AIRPORT(Airport_code) on delete no action on update no action
)

create table LEG_INSTANCE (
	Flight_number varchar(8),
	Leg_number int,
	Date date,
	Number_of_available_seats int not null,
	Airplane_id int not null,
	Departure_airport_code varchar(3) not null,
	Departure_time time(7) not null,
	Arrival_airport_code varchar(3) not null,
	Arrival_time time(7) not null,
	primary key(Flight_number, Leg_number, Date),
	foreign key(Flight_number, Leg_number) references FLIGHT_LEG(Flight_number, Leg_number) on delete no action on update no action,
	foreign key(Airplane_id) references AIRPLANE(Airplane_id) on delete no action on update no action,
	foreign key(Departure_airport_code) references AIRPORT(Airport_code) on delete no action on update no action,
	foreign key(Arrival_airport_code) references AIRPORT(Airport_code) on delete no action on update no action
)

create table SEAT (
	Flight_number varchar(8),
	Leg_number int,
	Seat_number varchar(3),
	Date date,
	primary key(Flight_number, Leg_number, Date, Seat_number),
	foreign key(Flight_number, Leg_number, Date) references LEG_INSTANCE(Flight_number, Leg_number, Date) on delete cascade on update cascade
)

create table FFC (
	Customer_id int,
	Flight_count int not null,
	Milage int not null,
	primary key(Customer_id)
)

create table CUSTOMER (
	Passport_number varchar(16),
	Name varchar(32) not null,
	Phone varchar(16) not null,
	Address varchar(64),
	email varchar(32),
	Country varchar(16) not null,
	Customer_id int not null,
	primary key(Passport_number),
	foreign key(Customer_id) references FFC(Customer_id) on delete cascade on update cascade
)

create table RESERVE (
	Flight_number varchar(8),
	Leg_number int,
	Date date,
	Passport_number varchar(16),
	primary key(Flight_number, Leg_number, Date, Passport_number),
	foreign key(Flight_number, Leg_number, Date) references LEG_INSTANCE(Flight_number, Leg_number, Date) on delete cascade on update cascade,
	foreign key(Passport_number) references CUSTOMER(Passport_number) on delete cascade on update cascade
)

create table COMPANY (
	Company_id int,
	Name varchar(32) not null,
	Product_count int not null,
	Flight_count int not null,
	isAirplane_company bit not null,
	isAirline_company bit not null,
	primary key(Company_id)
)

/*CHECK CONSTRAINTS*/
alter table FLIGHT add constraint check_flight_weekdays
check (weekdays in ('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'));

alter table AIRPLANE_TYPE add constraint check_airplane_type_max_seats
check (max_seats<=850);

alter table LEG_INSTANCE add constraint check_leg_instance_time
check (Departure_time!=Arrival_time);

alter table FLIGHT_LEG add constraint check_flight_leg_time
check (Scheduled_departure_time!=Scheduled_arrival_time);

alter table FLIGHT_LEG add constraint check_flight_leg_code
check (Departure_airport_code!=Arrival_airport_code);

alter table FARE add constraint check_amount
check (amount>=0);

/*ASSERTIONS*/
create trigger seat_ranking1 on	AIRPLANE
after insert
as begin
declare @Total_number_of_seats int, @Airplane_type varchar(16), @Max_seats int
select @Total_number_of_seats=Total_number_of_seats, @Airplane_type=Airplane_type, @Max_seats=Max_seats
from AIRPLANE_TYPE inner join inserted on AIRPLANE_TYPE.Airplane_type_name=inserted.Airplane_type
if @Total_number_of_seats>@Max_seats
begin
rollback transaction
raiserror('Total_number_of_seats cannot be greater than Max_seats',16,1)
end
end

create trigger seat_ranking2 on	LEG_INSTANCE
after insert
as begin
declare @Number_of_available_seats int, @Airplane_id int, @Total_number_of_seats int
select @Number_of_available_seats=Number_of_available_seats, @Total_number_of_seats=Total_number_of_seats
from AIRPLANE inner join inserted on AIRPLANE.Airplane_id=inserted.Airplane_id
if @Number_of_available_seats>@Total_number_of_seats
begin
rollback transaction
raiserror('Number_of_available_seats cannot be greater than Total_number_of_seats',16,1)
end
end

/*TRIGGERS*/
create trigger decrement_seat on SEAT
after insert
as begin
declare @Flight_number varchar(8), @Leg_number int, @Date date
select @Flight_number=Flight_number, @Leg_number=Leg_number, @Date=Date from inserted
update LEG_INSTANCE set Number_of_available_seats=Number_of_available_seats-1
where LEG_INSTANCE.Flight_number=@Flight_number and LEG_INSTANCE.Leg_number=@Leg_number and LEG_INSTANCE.Date=@Date
end

create trigger inserting_company_and_type on AIRPLANE_TYPE
for insert
as begin
declare @Airplane_type_name varchar(16)
select @Airplane_type_name=Airplane_type_name from inserted
if @Airplane_type_name like 'Boeing%'
begin
update AIRPLANE_TYPE set Company='Boeing'
where Airplane_type_name=@Airplane_type_name
end
if @Airplane_type_name like 'Airbus%'
begin
update AIRPLANE_TYPE set Company='Airbus'
where Airplane_type_name=@Airplane_type_name
end
if @Airplane_type_name like 'Antonov%'
begin
update AIRPLANE_TYPE set Company='Antonov'
where Airplane_type_name=@Airplane_type_name
end
if @Airplane_type_name like 'Tupolev%'
begin
update AIRPLANE_TYPE set Company='Tupolev'
where Airplane_type_name=@Airplane_type_name
end
if @Airplane_type_name like 'Embraer%'
begin
update AIRPLANE_TYPE set Company='Embraer'
where Airplane_type_name=@Airplane_type_name
end
end

create trigger total_amount on FARE
after insert
as begin
declare @Flight_number varchar(8), @Fare_code int, @Baggage_weight int, @Restrictions bit
select @Flight_number=Flight_number, @Fare_code=Fare_code, @Baggage_weight=Baggage_weight, @Restrictions=Restrictions from inserted
if @Restrictions=1 and @Baggage_weight>20
begin
update FARE set Amount=Amount+(@Baggage_weight-20)*8
where Flight_number=@Flight_number and @Fare_code=Fare_code 
end
end

/*DATA VALUES*/
/*for AIRPORT table*/
insert into AIRPORT values ('IST','Atatürk Airport','Istanbul','Turkey')
insert into AIRPORT values ('ADB','Adnan Menderes Airport','Izmir','Turkey')
insert into AIRPORT values ('ATL','H. Jackson Atlanta Airport','Atlanta/Georgia','United Sates')
insert into AIRPORT values ('PEK','Beijing Capital Airport','Beijing','China')
insert into AIRPORT values ('DXB','Dubai International Airport','Dubai','UAE')
insert into AIRPORT values ('CDG','Charles de Gaulle Airport','Paris','France')
insert into AIRPORT values ('LHR','Heathrow Airport','London','United Kingdom')
insert into AIRPORT values ('FRA','Frankfurt Airport','Frankfurt','Germany')
insert into AIRPORT values ('LAX','Los Angeles Airport','LA/California','United States')
insert into AIRPORT values ('AMS','Amsterdam Airport Schiphol','Amsterdam','The Netherlands')
insert into AIRPORT values ('ICN','Seoul Incheon Airport','Seoul','South Korea')
insert into AIRPORT values ('MAD','Madrid Barajas Airport','Madrid','Spain')
insert into AIRPORT values ('DEL','Indira Gandhi Airport','Delhi','India')
insert into AIRPORT values ('HND','Tokyo International Airport','Tokyo','Japan')
insert into AIRPORT values ('CIA','Ciampino Airport','Roma','Italy')

/*for FLIGHT table*/
insert into FLIGHT values ('PC1864','Pegasus Airlines','Sunday') 
insert into FLIGHT values ('TK2969','Turkish Airlines','Friday') 
insert into FLIGHT values ('UA844','United Airlines','Thursday')
insert into FLIGHT values ('AF5321','Air France','Wednesday')
insert into FLIGHT values ('AZ608','Alitalia','Wednesday')
insert into FLIGHT values ('AI636','Air India','Saturday') --
insert into FLIGHT values ('QR517','Qatar Airways','Tuesday')
insert into FLIGHT values ('EY58','Etihad Airways','Tuesday') --
insert into FLIGHT values ('NH74','All Nippon Airways','Monday')
insert into FLIGHT values ('KE19','Korean Airways','Saturday')
insert into FLIGHT values ('EK27','Emirates','Sunday') --
insert into FLIGHT values ('AA1379','American Airlines','Monday') --
insert into FLIGHT values ('BA1342','British Airways','Thursday')
insert into FLIGHT values ('UX92','Air Europa','Friday') 
insert into FLIGHT values ('CZ6715','China Southern Airlines','Saturday')

/*for AIRPLANE_TYPE table*/
insert into AIRPLANE_TYPE values ('Airbus-A380',616,'Airbus')
insert into AIRPLANE_TYPE values ('Boeing-747',469,'Boeing')
insert into AIRPLANE_TYPE values ('Boeing-737',495,'Boeing')
insert into AIRPLANE_TYPE values ('Tupolev-204',441,'Tupolev')
insert into AIRPLANE_TYPE values ('Embraer-190',467,'Embraer')
insert into AIRPLANE_TYPE values ('Boeing-777',752,'Boeing')
insert into AIRPLANE_TYPE values ('Antonov-72',454,'Antonov')
insert into AIRPLANE_TYPE values ('Embraer-170',398,'Embraer')
insert into AIRPLANE_TYPE values ('Airbus-A320',502,'Airbus')
insert into AIRPLANE_TYPE values ('Airbus-A320s',557,'Airbus')
insert into AIRPLANE_TYPE values ('Airbus-A380s',703,'Airbus')
insert into AIRPLANE_TYPE values ('Tupolev-154',413,'Tupolev')
insert into AIRPLANE_TYPE values ('Embraer-195',499,'Embraer')
insert into AIRPLANE_TYPE values ('Boeing-757',558,'Boeing')
insert into AIRPLANE_TYPE values ('Boeing-767',633,'Boeing')

/*for AIRPLANE table*/
insert into AIRPLANE values (101,362,'Airbus-A320')
insert into AIRPLANE values (102,379,'Airbus-A320s')
insert into AIRPLANE values (103,481,'Airbus-A380')
insert into AIRPLANE values (104,503,'Airbus-A380s')
insert into AIRPLANE values (105,312,'Antonov-72')
insert into AIRPLANE values (106,364,'Boeing-737')
insert into AIRPLANE values (107,366,'Boeing-747')
insert into AIRPLANE values (108,432,'Boeing-757')
insert into AIRPLANE values (109,501,'Boeing-767')
insert into AIRPLANE values (201,541,'Boeing-777')
insert into AIRPLANE values (202,289,'Embraer-170')
insert into AIRPLANE values (203,334,'Embraer-190')
insert into AIRPLANE values (204,375,'Embraer-195')
insert into AIRPLANE values (205,277,'Tupolev-154')
insert into AIRPLANE values (206,309,'Tupolev-204')

/*for CAN_LAND table*/
insert into CAN_LAND values ('Airbus-A380s','ATL')
insert into CAN_LAND values ('Airbus-A320s','PEK')
insert into CAN_LAND values ('Tupolev-204','DEL')
insert into CAN_LAND values ('Boeing-767','FRA')
insert into CAN_LAND values ('Boeing-737','ADB')
insert into CAN_LAND values ('Airbus-A380s','LAX')
insert into CAN_LAND values ('Boeing-757','CDG')
insert into CAN_LAND values ('Embraer-195','LHR')
insert into CAN_LAND values ('Boeing-777','ATL')
insert into CAN_LAND values ('Boeing-747','IST')
insert into CAN_LAND values ('Airbus-A320s','HND')
insert into CAN_LAND values ('Embraer-195','LAX')
insert into CAN_LAND values ('Boeing-777','DXB')
insert into CAN_LAND values ('Tupolev-204','MAD')
insert into CAN_LAND values ('Boeing-747','CDG')
insert into CAN_LAND values ('Boeing-737','CIA')
insert into CAN_LAND values ('Airbus-A320s','ICN')
insert into CAN_LAND values ('Boeing-767','AMS')

/*for FARE table*/
insert into FARE values ('AA1379',1001,175,0,25)
insert into FARE values ('AF5321',1002,80,1,17)
insert into FARE values ('AI636',1003,110,1,21)
insert into FARE values ('AZ608',1004,65,1,12)
insert into FARE values ('BA1342',1005,90,1,14)
insert into FARE values ('CZ6715',1006,130,1,26)
insert into FARE values ('EK27',1007,210,0,19)
insert into FARE values ('EY58',1008,155,1,23)
insert into FARE values ('KE19',1009,45,1,15)
insert into FARE values ('NH74',1010,70,1,12)
insert into FARE values ('PC1864',1011,30,1,22)
insert into FARE values ('QR517',1012,235,0,13)
insert into FARE values ('TK2969',1013,90,1,24)
insert into FARE values ('UA844',1014,180,1,20)
insert into FARE values ('UX92',1015,60,1,21)

/*for FLIGHT_LEG table*/
insert into FLIGHT_LEG values ('PC1864',1,'ADB','12/17/2017 11:30','IST','12/17/2017 12:45')
insert into FLIGHT_LEG values ('AF5321',1,'CDG','12/13/2017 20:45','FRA','12/13/2017 22:00')
insert into FLIGHT_LEG values ('NH74',1,'HND','12/11/2017 13:55','ICN','12/11/2017 16:35')
insert into FLIGHT_LEG values ('TK2969',1,'IST','12/15/2017 14:50','AMS','12/15/2017 16:45')
insert into FLIGHT_LEG values ('BA1342',1,'LHR','12/14/2017 15:10','MAD','12/14/2017 17:35')
insert into FLIGHT_LEG values ('CZ6715',1,'DEL','12/16/2017 07:10','PEK','12/16/2017 12:55')
insert into FLIGHT_LEG values ('AZ608',1,'CIA','12/13/2017 11:10','LHR','12/13/2017 14:00')
insert into FLIGHT_LEG values ('UA844',1,'ATL','12/14/2017 08:20','LAX','12/14/2017 13:35')
insert into FLIGHT_LEG values ('KE19',1,'ICN','12/16/2017 09:20','PEK','12/16/2017 10:35')
insert into FLIGHT_LEG values ('UX92',1,'AMS','12/15/2017 12:30','FRA','12/15/2017 13:35')
insert into FLIGHT_LEG values ('QR517',1,'CDG','12/12/2017 11:30','IST','12/12/2017 15:00')
insert into FLIGHT_LEG values ('PC1864',2,'IST','12/17/2017 14:00','AMS','12/17/2017 17:45')
insert into FLIGHT_LEG values ('TK2969',2,'AMS','12/15/2017 19:00','LAX','12/16/2017 06:00')
insert into FLIGHT_LEG values ('KE19',2,'PEK','12/16/2017 13:10','HND','12/16/2017 17:30')
insert into FLIGHT_LEG values ('UX92',2,'FRA','12/15/2017 15:00','IST','12/15/2017 18:00')
insert into FLIGHT_LEG values ('AZ608',2,'LHR','12/13/2017 16:30','ATL','12/14/2017 02:05')
insert into FLIGHT_LEG values ('QR517',2,'IST','12/12/2017 16:30','DXB','12/12/2017 22:45')

/*for LEG_INSTANCE table*/
insert into LEG_INSTANCE values ('PC1864',1,'12/17/2017',210,106,'ADB','11:32','IST','12:55')
insert into LEG_INSTANCE values ('AF5321',1,'12/13/2017',335,108,'CDG','20:45','FRA','22:00')
insert into LEG_INSTANCE values ('NH74',1,'12/11/2017',303,102,'HND','13:55','ICN','16:35')
insert into LEG_INSTANCE values ('TK2969',1,'12/15/2017',280,107,'IST','15:05','AMS','17:10')
insert into LEG_INSTANCE values ('BA1342',1,'12/14/2017',252,204,'LHR','15:15','MAD','17:40')
insert into LEG_INSTANCE values ('CZ6715',1,'12/16/2017',214,206,'DEL','07:20','PEK','13:05')
insert into LEG_INSTANCE values ('AZ608',1,'12/13/2017',263,106,'CIA','11:10','LHR','14:00')
insert into LEG_INSTANCE values ('UA844',1,'12/14/2017',381,104,'ATL','08:45','LAX','14:00')
insert into LEG_INSTANCE values ('KE19',1,'12/16/2017',223,102,'ICN','09:30','PEK','10:45')
insert into LEG_INSTANCE values ('UX92',1,'12/15/2017',365,109,'AMS','12:30','FRA','13:35')
insert into LEG_INSTANCE values ('QR517',1,'12/12/2017',267,107,'CDG','11:35','IST','15:10')
insert into LEG_INSTANCE values ('PC1864',2,'12/17/2017',210,106,'IST','16:30','AMS','20:15')
insert into LEG_INSTANCE values ('TK2969',2,'12/15/2017',280,107,'AMS','19:00','LAX','06:00')
insert into LEG_INSTANCE values ('KE19',2,'12/16/2017',223,102,'PEK','14:40','HND','19:00')
insert into LEG_INSTANCE values ('UX92',2,'12/15/2017',365,109,'FRA','15:15','IST','18:00')
insert into LEG_INSTANCE values ('AZ608',2,'12/13/2017',263,106,'LHR','17:00','ATL','02:40')
insert into LEG_INSTANCE values ('QR517',2,'12/12/2017',267,107,'IST','11:35','ADB','13:00')

/*for SEAT table*/
insert into SEAT values ('PC1864',1,'12F','12/17/2017')
insert into SEAT values ('PC1864',1,'6B','12/17/2017')
insert into SEAT values ('AF5321',1,'25C','12/13/2017')
insert into SEAT values ('AF5321',1,'14B','12/13/2017')
insert into SEAT values ('NH74',1,'11A','12/11/2017')
insert into SEAT values ('NH74',1,'12A','12/11/2017')
insert into SEAT values ('TK2969',1,'21D','12/15/2017')
insert into SEAT values ('TK2969',1,'19B','12/15/2017')
insert into SEAT values ('BA1342',1,'13A','12/14/2017')
insert into SEAT values ('BA1342',1,'11F','12/14/2017')
insert into SEAT values ('CZ6715',1,'14E','12/16/2017')
insert into SEAT values ('CZ6715',1,'13B','12/16/2017')
insert into SEAT values ('AZ608',1,'11D','12/13/2017')
insert into SEAT values ('AZ608',1,'8E','12/13/2017')
insert into SEAT values ('UA844',1,'1A','12/14/2017')
insert into SEAT values ('UA844',1,'8D','12/14/2017')
insert into SEAT values ('KE19',1,'15C','12/16/2017')
insert into SEAT values ('KE19',1,'14A','12/16/2017')
insert into SEAT values ('UX92',1,'18B','12/15/2017')
insert into SEAT values ('UX92',1,'11D','12/15/2017')
insert into SEAT values ('QR517',1,'18C','12/12/2017')
insert into SEAT values ('QR517',1,'31A','12/12/2017')
insert into SEAT values ('PC1864',2,'27F','12/17/2017')
insert into SEAT values ('PC1864',2,'15C','12/17/2017')
insert into SEAT values ('TK2969',2,'14B','12/15/2017')
insert into SEAT values ('TK2969',2,'24E','12/15/2017')
insert into SEAT values ('KE19',2,'13A','12/16/2017')
insert into SEAT values ('KE19',2,'11F','12/16/2017')
insert into SEAT values ('UX92',2,'11B','12/15/2017')
insert into SEAT values ('UX92',2,'30C','12/15/2017')
insert into SEAT values ('AZ608',2,'14E','12/13/2017')
insert into SEAT values ('AZ608',2,'10A','12/13/2017')
insert into SEAT values ('QR517',2,'22B','12/12/2017')
insert into SEAT values ('QR517',2,'14F','12/12/2017')

/*for FFC table*/
insert into FFC values (1,2,1577)
insert into FFC values (2,1,203)
insert into FFC values (3,1,297)
insert into FFC values (4,1,297)
insert into FFC values (5,1,718)
insert into FFC values (6,1,718)
insert into FFC values (7,2,6815)
insert into FFC values (8,1,1375)
insert into FFC values (9,1,785)
insert into FFC values (10,1,785)
insert into FFC values (11,1,2350)
insert into FFC values (12,1,2350)
insert into FFC values (13,1,891)
insert into FFC values (14,2,5097)
insert into FFC values (15,1,1935)
insert into FFC values (16,1,1935)
insert into FFC values (17,2,1893)
insert into FFC values (18,1,592)
insert into FFC values (19,2,1387)
insert into FFC values (20,1,226)
insert into FFC values (21,1,1403)
insert into FFC values (22,2,3264)
insert into FFC values (23,1,1375)
insert into FFC values (24,1,5440)
insert into FFC values (25,1,1301)
insert into FFC values (26,1,1161)
insert into FFC values (27,1,4206)
insert into FFC values (28,1,1861)

/*for CUSTOMER table*/
insert into CUSTOMER values (100001,'Kemalettin Tuğcu','05053265414',null,null,'Turkey',1)
insert into CUSTOMER values (100002,'Cemal Tonga','05366874125',null,null,'Turkey',2)
insert into CUSTOMER values (100003,'Tony Parker','565413322',null,null,'France',3)
insert into CUSTOMER values (100004,'Antoine Griezmann','656565889',null,null,'France',4)
insert into CUSTOMER values (100005,'Uchiha Itachi','6468641351',null,null,'Japan',5)
insert into CUSTOMER values (100006,'Hattori Hanzo','8742123',null,null,'Japan',6)
insert into CUSTOMER values (100007,'Serdar Ortaç','0588123654',null,null,'Turkey',7)
insert into CUSTOMER values (100008,'Aleyna Tilki','612354798',null,null,'Turkey',8)
insert into CUSTOMER values (100009,'Sir Alex Ferguson','7856464651',null,null,'United Kingdom',9)
insert into CUSTOMER values (100010,'Andy Murray','31351545',null,null,'United Kingdom',10)
insert into CUSTOMER values (100011,'Yao Ming','312351541',null,null,'China',11)
insert into CUSTOMER values (100012,'Lucy Liu','132135465',null,null,'China',12)
insert into CUSTOMER values (100013,'Francesco Totti','32432434',null,null,'Italy',13)
insert into CUSTOMER values (100014,'Alessandra Ambrosio','123124556',null,null,'Italy',14)
insert into CUSTOMER values (100015,'Margot Robbie','12412556',null,null,'Australia',15)
insert into CUSTOMER values (100016,'Gal Gadot','124555624',null,null,'Israel',16)
insert into CUSTOMER values (100017,'Park Ji-Sung','12354325',null,null,'South Korea',17)
insert into CUSTOMER values (100018,'Son Heung-Min','124325569',null,null,'South Korea',18)
insert into CUSTOMER values (100019,'Dirk Kuyt','564646545',null,null,'The Netherlands',19)
insert into CUSTOMER values (100020,'Ryan Babel','66564512',null,null,'The Netherlands',20)
insert into CUSTOMER values (100021,'Didier Deschamps','263465312',null,null,'France',21)
insert into CUSTOMER values (100022,'Emmanuelle Mimieux','134465602',null,null,'France',22)
insert into CUSTOMER values (100023,'Sabahattin Ali','05411223545',null,null,'Turkey',23)
insert into CUSTOMER values (100024,'Nazım Hikmet Ran','0541616656',null,null,'Turkey',24)
insert into CUSTOMER values (100025,'Bae Doona','34554646',null,null,'South Korea',25)
insert into CUSTOMER values (100026,'Robin van Persie','13215647',null,null,'The Netherlands',26)
insert into CUSTOMER values (100027,'Pierluigi Collina','26515615',null,null,'Italy',27)
insert into CUSTOMER values (100028,'Nasser Al-Khelaifi','134465602',null,null,'Qatar',28)

/*for RESERVE table*/
insert into RESERVE values ('PC1864',1,'12/17/2017',100001)
insert into RESERVE values ('PC1864',1,'12/17/2017',100002)
insert into RESERVE values ('AF5321',1,'12/13/2017',100003)
insert into RESERVE values ('AF5321',1,'12/13/2017',100004)
insert into RESERVE values ('NH74',1,'12/11/2017',100005)
insert into RESERVE values ('NH74',1,'12/11/2017',100006)
insert into RESERVE values ('TK2969',1,'12/15/2017',100007)
insert into RESERVE values ('TK2969',1,'12/15/2017',100008)
insert into RESERVE values ('BA1342',1,'12/14/2017',100009)
insert into RESERVE values ('BA1342',1,'12/14/2017',100010)
insert into RESERVE values ('CZ6715',1,'12/16/2017',100011)
insert into RESERVE values ('CZ6715',1,'12/16/2017',100012)
insert into RESERVE values ('AZ608',1,'12/13/2017',100013)
insert into RESERVE values ('AZ608',1,'12/13/2017',100014)
insert into RESERVE values ('UA844',1,'12/14/2017',100015)
insert into RESERVE values ('UA844',1,'12/14/2017',100016)
insert into RESERVE values ('KE19',1,'12/16/2017',100017)
insert into RESERVE values ('KE19',1,'12/16/2017',100018)
insert into RESERVE values ('UX92',1,'12/15/2017',100019)
insert into RESERVE values ('UX92',1,'12/15/2017',100020)
insert into RESERVE values ('QR517',1,'12/12/2017',100021)
insert into RESERVE values ('QR517',1,'12/12/2017',100022)
insert into RESERVE values ('PC1864',2,'12/17/2017',100001)
insert into RESERVE values ('PC1864',2,'12/17/2017',100023)
insert into RESERVE values ('TK2969',2,'12/15/2017',100007)
insert into RESERVE values ('TK2969',2,'12/15/2017',100024)
insert into RESERVE values ('KE19',2,'12/16/2017',100017)
insert into RESERVE values ('KE19',2,'12/16/2017',100025)
insert into RESERVE values ('UX92',2,'12/15/2017',100019)
insert into RESERVE values ('UX92',2,'12/15/2017',100026)
insert into RESERVE values ('AZ608',2,'12/13/2017',100014)
insert into RESERVE values ('AZ608',2,'12/13/2017',100027)
insert into RESERVE values ('QR517',2,'12/12/2017',100022)
insert into RESERVE values ('QR517',2,'12/12/2017',100028)

/*for COMPANY table*/
insert into COMPANY values (301,'Pegasus Airlines',2,2,0,1)
insert into COMPANY values (302,'Turkish Airlines',2,2,0,1)
insert into COMPANY values (303,'United Airlines',1,1,0,1)
insert into COMPANY values (304,'Air France',1,1,0,1)
insert into COMPANY values (305,'Alitalia',1,2,0,1)
insert into COMPANY values (306,'Air India',1,0,0,1)
insert into COMPANY values (307,'Qatar Airways',2,2,0,1)
insert into COMPANY values (308,'Etihad Airways',1,0,0,1)
insert into COMPANY values (309,'All Nippon Airways',1,1,0,1)
insert into COMPANY values (310,'Korean Airways',2,2,0,1)
insert into COMPANY values (311,'Emirates',1,0,0,1)
insert into COMPANY values (312,'American Airlines',1,0,0,1)
insert into COMPANY values (313,'British Airways',1,1,0,1)
insert into COMPANY values (314,'Air Europa',2,2,0,1)
insert into COMPANY values (315,'China Southern Airlines',1,1,0,1)
insert into COMPANY values (501,'Airbus',4,4,1,0)
insert into COMPANY values (502,'Antonov',1,0,1,0)
insert into COMPANY values (503,'Boeing',5,8,1,0)
insert into COMPANY values (504,'Embraer',3,1,1,0)
insert into COMPANY values (505,'Tupolev',2,1,1,0)

/*SQL STATEMENTS*/
select distinct CUSTOMER.Passport_number, Name, Flight_number
from RESERVE, CUSTOMER
where CUSTOMER.Passport_number=RESERVE.Passport_number 
and Flight_number='QR517'

select FFC.Customer_id, Name, Country, Milage
from FFC, CUSTOMER
where FFC.Customer_id=CUSTOMER.Customer_id
and Country='Turkey'

select Airline, Flight_number, Flight_count
from COMPANY, FLIGHT
where COMPANY.Name=FLIGHT.Airline
and Name='Emirates'

select Name, Flight_number, Milage
from FFC, CUSTOMER, RESERVE
where FFC.Customer_id=CUSTOMER.Customer_id
and CUSTOMER.Passport_number=RESERVE.Passport_number
and Flight_count=1 and Milage>2000

select FFC.Customer_id, Name, Flight_number, Date, Milage
from CUSTOMER, RESERVE, FFC
where FFC.Customer_id=CUSTOMER.Customer_id
and CUSTOMER.Passport_number=RESERVE.Passport_number
and Name='Hattori Hanzo'

select Airplane_id, Name, Airplane_type, Max_seats, Flight_count, Product_count
from COMPANY, AIRPLANE_TYPE, AIRPLANE
where AIRPLANE_TYPE.Company=COMPANY.Name
and AIRPLANE_TYPE.Airplane_type_name=AIRPLANE.Airplane_type
and Name='Antonov'

select distinct RESERVE.Flight_number, Departure_airport_code, Arrival_airport_code, RESERVE.Date, Seat_number
from LEG_INSTANCE, SEAT, RESERVE
where LEG_INSTANCE.Flight_number=RESERVE.Flight_number
and LEG_INSTANCE.Flight_number=SEAT.Flight_number
and RESERVE.Date='12/14/2017'

select distinct LEG_INSTANCE.Flight_number, RESERVE.Date, Departure_airport_code, Arrival_airport_code, Milage, Name
from LEG_INSTANCE, FFC, CUSTOMER, RESERVE
where LEG_INSTANCE.Flight_number=RESERVE.Flight_number
and CUSTOMER.Passport_number=RESERVE.Passport_number
and FFC.Customer_id=CUSTOMER.Customer_id
and LEG_INSTANCE.Flight_number='BA1342'

select distinct FFC.Customer_id, RESERVE.Passport_number, Name, Phone, LEG_INSTANCE.Date
from FFC, CUSTOMER, RESERVE, LEG_INSTANCE
where FFC.Customer_id=CUSTOMER.Customer_id
and LEG_INSTANCE.Flight_number=RESERVE.Flight_number
and CUSTOMER.Passport_number=RESERVE.Passport_number
and Flight_count=2

select RESERVE.Flight_number, RESERVE.Leg_number, Arrival_airport_code, Name, Flight_count, Milage 
from LEG_INSTANCE, CUSTOMER, RESERVE, FFC
where LEG_INSTANCE.Flight_number=RESERVE.Flight_number
and LEG_INSTANCE.Leg_number=RESERVE.Leg_number
and CUSTOMER.Passport_number=RESERVE.Passport_number
and FFC.Customer_id=CUSTOMER.Customer_id
and Departure_airport_code='IST'

select distinct CUSTOMER.Passport_number, Name, Flight_number
from RESERVE, CUSTOMER
where CUSTOMER.Passport_number=RESERVE.Passport_number
and Flight_number in (
	select Flight_number
	from RESERVE
	where Flight_number='AZ608'
)

select FFC.Customer_id, Name, Country, Milage
from FFC, CUSTOMER
where FFC.Customer_id=CUSTOMER.Customer_id
and Country in (
	select Country
	from CUSTOMER
	where Country='France'
)

select Airline, Flight_number, Flight_count
from COMPANY, FLIGHT
where COMPANY.Name=FLIGHT.Airline
and Name in (
	select Name
	from COMPANY
	where Name='Qatar Airways'
)

select distinct Name, Flight_number, Milage
from FFC, CUSTOMER, RESERVE
where FFC.Customer_id=CUSTOMER.Customer_id
and CUSTOMER.Passport_number=RESERVE.Passport_number
and Flight_count=2
and Milage in (
	select Milage
	from FFC
	where Milage>3000
)

select Flight_number, Leg_number, Date, Seat_number
from SEAT
where exists (
	select *
	from LEG_INSTANCE
	where SEAT.Flight_number=LEG_INSTANCE.Flight_number
	and SEAT.Leg_number=LEG_INSTANCE.Leg_number
	and SEAT.Date=LEG_INSTANCE.Date
)

/**/

select *
from CUSTOMER full outer join RESERVE
on CUSTOMER.Passport_number=RESERVE.Passport_number

select *
from COMPANY left outer join FLIGHT
on COMPANY.Name=FLIGHT.Airline
where isAirline_company=1

select *
from FFC right outer join CUSTOMER
on FFC.Customer_id=CUSTOMER.Customer_id

/*VIEWS*/
create view view1 as (
	select FFC.Customer_id, Name, Milage
	from FFC, CUSTOMER
	where FFC.Customer_id=CUSTOMER.Customer_id
	and Flight_count=1
)

create view view2 as (
	select *
	from COMPANY
	where isAirline_company=1
)

create view view3 as (
	select *
	from COMPANY
	where isAirplane_company=1
)