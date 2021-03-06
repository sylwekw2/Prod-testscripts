-- Programowanie i test SHT-P
-- data 24.02.2020
-- autor: Sylwester Wieteska
---------------------------------------------------------------------------------------------
--comm_log()
script_ver = "1.2.2"
--[[
History
1.2.2	- zmiana dop zakresu Sigma 0-20
1.2.0	- dodanie zapisu do bazy z rfid_id jako SN
1.0.0	- pierwsza wersja skryptu
]]--

--============================================================================================
-- ZMIENNE i STAŁE
--============================================================================================
typ = "SHT-P"
--poczatek_SN = 123	--0x7B hex
tt = 1
hw_version = "1.1" -- LRA/AM-100
firmware_w = "0.7.5"
--sigma_max = 6000

xt = os.clock() --poczatek liczenia czasu wykonywania skryptu

_date = os.date("%d/%m/%Y")..os.date(" %X")
print("# TST-"..typ.." "..script_ver.." # Data: " .. _date .."\n")

function init_var()
	local path = tostring(os.getenv("PATH"))
	--print(path)
	if ( string.find(path, "Program Files (x86)", 1, true)~=nil ) then 
		x64 = 1
		st_link_cli = "\"C:\\Program Files (x86)\\STMicroelectronics\\STM32 ST-LINK Utility\\ST-LINK Utility\\ST-LINK_CLI.exe\" " 
	else
		x64 = 0
		st_link_cli = "\"C:\\Program Files\\STMicroelectronics\\STM32 ST-LINK Utility\\ST-LINK Utility\\ST-LINK_CLI.exe\" "
	end
	print("x64? : "..x64)

	appdata = tostring(os.getenv("APPDATA"))
	--print (appdata)
	appdata = string.gsub(appdata, "\\", "\\\\")
	--print (appdata)
end

function set_programming_script(merase)
	local batdata = ""
	
	firmware_SHT_P = firmware_SHT_P
		
	os.rename(firmware_SHT_P, firmware_SHT_P..".hex")
	firmware_SHT_P_hex = firmware_SHT_P..".hex"
	
	batdata = "Title Programowanie "..typ.."\n"
	if merase==0 then
		batdata = batdata..st_link_cli.."-c SWD UR -P \""..firmware_SHT_P_hex.."\" -V while_programming -OB RDP=0 BOR_LEV=0 -rOB -HardRst PULSE=500\n"
	else
		batdata = batdata..st_link_cli.."-c SWD UR -ME -P \""..firmware_SHT_P_hex.."\" -V while_programming -OB RDP=0 BOR_LEV=0 -rOB -HardRst PULSE=500\n"
	end
	--batdata = batdata .."PAUSE\n"
		
	f = io.open(appdata.."\\Inventia\\Tester\\FileCache\\SHT_P_programuj.bat", "w")
	f:write(batdata)
	f:close()
end

function bt(x)
    local b1=x%256  x=(x-x%256)/256
    return string.char(b1)
end

function set_addr_sigma_bat_script(addr, sigma_max)
	local batdata = ""
	local sigma_addr_hex, sigma_addr_nhex = 0, 0
	local sig1, sig2, sig3, sig4 = 0,0,0,0
	
	print("Adres: "..addr.." Sigma: "..sigma_max)
	sigma_addr_hex =  create_32_value(0x30+addr, tonumber(sigma_max))
	print("sigma_addr hex: "..string.format("%08X", sigma_addr_hex))
	sig1 = shiftr(sigma_addr_hex, 24)
	sig2 = shiftr(shiftl(sigma_addr_hex,8), 24)
	sig3 = shiftr(shiftl(sigma_addr_hex,16), 24)
	sig4 = shiftr(shiftl(sigma_addr_hex,24), 24)
	--print(string.format("%02X",sig1))
	--print(string.format("%02X",sig2))
	--print(string.format("%02X",sig3))
	--print(string.format("%02X",sig4))
	--print(string.format("%02X",not_proc(sig4)))
	
	f = io.open(appdata.."\\Inventia\\Tester\\FileCache\\SHTP_conf.bin", "wb")
	f:write( bt(sig4), bt(sig3), bt(sig2), bt(sig1) ) -- w pliku bin odwrotna kolejność bajtów
	f:write( bt(and_proc(not_proc(sig4), 0xFF)), bt(and_proc(not_proc(sig3), 0xFF)) )
	f:write( bt(and_proc(not_proc(sig2), 0xFF)), bt(and_proc(not_proc(sig1), 0xFF)) )
	f:close()
	
	batdata = "Title Programowanie adresu SHT-P "..tostring(addr).." i sigma_max "..sigma_max.."\n"
	batdata = batdata..st_link_cli.."-c SWD UR -P \""..appdata.."\\Inventia\\Tester\\FileCache\\SHTP_conf.bin\" 0x801F000 -V while_programming -HardRst PULSE=500\n"
	--batdata = batdata .. "pause\n"
		
	f = io.open(appdata.."\\Inventia\\Tester\\FileCache\\Programuj_SHTP_conf.bat", "w")
	f:write(batdata)
	f:close()
end

function programming_SHTP(shtp_no)
	local prg1, prg2 = 0, 0
	
	msg_box("Podłącz programator do najnizszego ustroju pomiarowego nr 1")
	if shtp_no=="SOLO" then 
		set_addr_sigma_bat_script(1, sigma_max)
		prg1 = os.execute("\""..appdata.."\\Inventia\\Tester\\FileCache\\SHT_P_programuj.bat\"")
		print("Status programowania: "..prg1)
		prg2 = os.execute("\""..appdata.."\\Inventia\\Tester\\FileCache\\Programuj_SHTP_conf.bat\"")
		print("Status programowania: "..prg2)

		if prg1 == 0 and prg2 == 0 then
			print("**** Programowanie zakończone OK****")
			return 1
		else
			print("**** Nie zaprogramowano ustroju pomiarowego ! ****")
			return -1
		end
		
	else -- TRIO
		set_addr_sigma_bat_script(1, sigma_max)
		prg1 = os.execute("\""..appdata.."\\Inventia\\Tester\\FileCache\\SHT_P_programuj.bat\"")
		print("Status programowania: "..prg1)
		prg2 = os.execute("\""..appdata.."\\Inventia\\Tester\\FileCache\\Programuj_SHTP_conf.bat\"")
		print("Status konfiguracji: "..prg2)

		if prg1 == 0 and prg2 == 0 then
			print("**** Programowanie ustroju nr 1 zakończone OK****")
			msg_box("Podlacz programator do drugiego (środkowego) ustroju pomiarowego nr 2")
			set_addr_sigma_bat_script(2, sigma_max)
			prg1 = os.execute("\""..appdata.."\\Inventia\\Tester\\FileCache\\SHT_P_programuj.bat\"")
			print("Status programowania: "..prg1)
			prg2 = os.execute("\""..appdata.."\\Inventia\\Tester\\FileCache\\Programuj_SHTP_conf.bat\"")
			print("Status konfiguracji: "..prg2)
			
			if prg1 == 0 and prg2 == 0 then
				print("**** Programowanie ustroju nr 2 zakończone OK****")
				msg_box("Podlacz programator do trzeciego (górnego) ustroju pomiarowego nr 3")
				set_addr_sigma_bat_script(3, sigma_max)
				prg1 = os.execute("\""..appdata.."\\Inventia\\Tester\\FileCache\\SHT_P_programuj.bat\"")
				print("Status programowania: "..prg1)
				prg2 = os.execute("\""..appdata.."\\Inventia\\Tester\\FileCache\\Programuj_SHTP_conf.bat\"")
				print("Status konfiguracji: "..prg2)
				
				if prg1 == 0 and prg2 == 0 then
					print("**** Programowanie ustroju nr 3 zakończone OK****")
					return 1
				else
					print("**** Nie zaprogramowano ustroju nr 3 ! ****")
					return -1
				end		
			else
				print("**** Nie zaprogramowano ustroju nr 2 ! ****")
				return -1
			end		
		else
			print("**** Nie zaprogramowano ustroju nr 1 ! ****")
			return -1
		end
	end
end

function send_comm_command( port, cmd )

	if (string.find(cmd, "+++", 1, true)~=nil) then 
		sleep(2000)
		comm_clear_buffer(port)
		comm_send_text(port, cmd)
		--comm_send_line(port, cmd)
		print("+++")
		sleep(3000)
	else
		comm_clear_buffer(port)
		--comm_send_line(port, cmd) 
		comm_send_text(port, cmd.."\013")
		print(cmd.."\n")
	end
end

function send_cmd_read_resp ( port, cmd, resp)
	local t=0
	tstart = os.clock()
	re=""
	local odp = nil
	send_comm_command(port, cmd)
	--sleep(100)
	while (odp==nil) and (t<=7) do
		re = comm_read_line(port)
		odp = string.find(re, resp, 1, true)
		print (">"..tostring(re))
		t= os.clock() - tstart
	end
	
	if odp== nil then return -1 else return 1 end
end

function read_resp ( port, resp)
	local t=0
	tstart = os.clock()
	re=""
	local odp = nil
	
	while (odp==nil) and (t<=7) do
		re = comm_read_line(port)
		odp = string.find(re, resp, 1, true)
		print (">"..tostring(re))
		t= os.clock() - tstart
	end
	
	if odp== nil then return -1 else return 1 end
end

function read_svalues(port, n)
	local svalue = {}
	local k, v = "", ""
	
	for i=1, n do
		if send_cmd_read_resp (port, i.."X\013", "DONE")<0 then
			return -1
		end

		if read_resp (port, "EPS") < 0 then
			return -1
		end
		
		for k, v in string.gmatch(re, "(%w+)=(%d+.%d+)") do
		   svalue[k] = v
		end

		t[i] = tonumber(svalue["T"])
		rh[i] = tonumber(svalue["RH"])
		mag[i] = tonumber(svalue["MAG"])
		phs[i] = tonumber(svalue["PHS"])
		eps[i] = tonumber(svalue["EPS"])
		sig[i] = tonumber(svalue["SIG"])

		sleep(500)
	end
end

function check_svalues(n)
	local i, ok = 1, 1
	
	print("")
	for i=1, n do
		if t[i]<10 or t[i]>35 then
			print("Temp. "..i..":		"..t[i].."	Błąd, dopuszczalny zakres(10..35)")
			ok = 0
		else
			print("Temp. "..i..":		"..t[i].."	OK")
		end
		if rh[i]<10 or rh[i]>85 then
			print("Wilgotność "..i..":		"..rh[i].."	Błąd, dopuszczalny zakres(10..85)")
			ok = 0
		else
			print("Wilgotność "..i..":		"..rh[i].."	OK")
		end
		if mag[i]<760 or mag[i]>870 then
			print("Amplituda "..i..":		"..mag[i].."	Błąd, dopuszczalny zakres(760..870)")
			ok = 0
		else
			print("Amplituda "..i..":		"..mag[i].."	OK")
		end
		if phs[i]<1500 or phs[i]>1720 then
			print("Faza "..i..":		"..phs[i].."	Błąd, dopuszczalny zakres(1500..1720)")
			ok = 0
		else
			print("Faza "..i..":		"..phs[i].."	OK")
		end
		if eps[i]<0.8 or eps[i]>1.2 then
			print("Epsilon "..i..":		"..eps[i].."	Błąd, dopuszczalny zakres(0.8..1.2)")
			ok = 0
		else
			print("Epsilon "..i..":		"..eps[i].."	OK")
		end
		if sig[i]<0 or sig[i]>20 then
			print("Sigma "..i..":		"..sig[i].."	Błąd, dopuszczalny zakres(0..20)")
			ok = 0
		else
			print("Sigma "..i..":		"..sig[i].."	OK")
		end
		print("")
	end	
	
	if ok==0 then
		return -1
	else
		return 1
	end
end

function read_RFID_tag() -- tag naklejany
	local try = 0
	
	rfid_id = rfid_get_id(10000)
	print("Odczytano: "..rfid_id.." "..string.len(rfid_id))
	while string.len(rfid_id)<14 and try < 3 do
		print("Oddal i przyłóż tag RFID ponownie... ")
		rfid_id = rfid_get_id(5000)
		print("Odczytano: "..rfid_id.." "..string.len(rfid_id))
		try = try +1
	end
	if try < 3 then
		rfid_beep()
		return 1
	else
		print("Odczytano za krótki identyfikator")
		return -1
	end
end

print ("******************** Programowanie i test "..typ.." v"..script_ver.." ******************")

init_var()
set_programming_script(0)
sleep(500)
nr_PCB=""

if shtp_no=="SOLO" then 
	print("Wersja SHTP: "..shtp_no.."\n")
	print("Odczytaj czytnikiem kod QR z płytki SHTP...")
	while nr_PCB == "" do
		nr_PCB = user_input("Odczytaj czytnikiem kod QR z płytki SHTP... i wciśnij OK")
	end
	--20/20002

else
	print("Wersja SHTP: "..shtp_no.."\n")
	print("Odczytaj czytnikiem kody QR z płytek SHTP...")
	while nr_PCB == "" do
		nr_PCB = user_input("Odczytaj czytnikiem kody QR z płytek SHTP... i wciśnij OK")
	end
	--20/20002
	--20/20003
	--20/20004
end

print (nr_PCB)
print("Sigma_max= "..sigma_max)

message = [[Podłacz kabel SHT-P <-> USB-UART urządzenia
(płytki nie mogą mieć przylutowanych elektrod blaszanych)
Ustaw zasilanie na 3.6V+-0.2V i włacz je.
Programator ST-Link podłacza się do zlacza 5pin (1-pin-kwadrat - czerwony przewód)]]
msg_box(message)
print(message)

klik = ask_box("*** Czy programowac "..typ.."?  ***\n")
print("*** Czy programowac "..typ.."?  ***")
if (klik) then
	print("Tak")
	if programming_SHTP(shtp_no)<0 then
		print("* Blad programowania *")
		return -1
	else
		print("")
		print("Odłącz programator")
		print("")
	end
else
	print("Nie")
end

sleep(1000)

print(nr_PCB)

id_dev=""

m= tonumber(m)
print("m="..m)
com_status = comm_open(m, 9600)
if com_status then
	print("COM SHT-P open OK\n")
else
	print("COM SHT-P open ERROR\n")
end

t={}
rh={}
mag={}
phs={}
eps={}
sig={}

if shtp_no=="SOLO" then
	read_svalues(m, 1)
	if check_svalues(1)<0 then
		return -1
	end
else
	read_svalues(m, 3)
	if check_svalues(3)<0 then
		return -1
	end
end

msg_box("Wklej do rury SHT-P tag Mifare-Ultralight i przyłóż rurę w ciągu 10s do czytnika... ")
print("Wklej do rury SHT-P tag Mifare-Ultralight i przyłóż rurę w ciągu 10s do czytnika... ")
if read_RFID_tag()<0 then
	return -1
end

print("Wyszukanie numeru PCB w bazie...")
id_dev = get_device_id_by_pcb (nr_PCB) 
if (id_dev=="") then
	id_dev = add_blank_device(typ)
	print('Utworzono nowe urządzenie '..typ)
	add_pcb(id_dev, nr_PCB)
	print('Dodano do urządzenia nr_PCB: '..nr_PCB)
else
	print("W bazie istnieje już urządzenie o nr PCB: "..nr_PCB..", ID_dev: "..id_dev)
end

serial = get_sn_by_id(id_dev)
if serial == "" then
	print('Urzadzenie nie posiada wpisanego SN w bazie')
	set_serial_number(id_dev, rfid_id)
	print('Ustawiono w urzadzeniu SN: '..rfid_id)
else
	print('Urzadzenie posiada wpisany w bazie SN: '..serial)
	while serial ~= rfid_id do
		
		klik = ask_box('SN i odczytany RFID_ID zgadzają sie!\n Czy odczytać tag RFID jeszcze raz w ciągu 10s?')
		if klik then
			if read_RFID_tag()<0 then
				return -1
			end
		else
			return -1
		end
		
	end
	print('SN i odczytany RFID_ID zgadzają sie. Dane zostaną dołaczone do istniejących')
end

set_device_hardware_version(id_dev, hw_version)
print("Hardware: "..hw_version.."   OK")
set_device_firmware_version(id_dev, firmware_w)
print("Firmware: "..firmware_w.."   OK")


print("Odłącz baterię/zasilacz od płytki urządzenia...\n\n")	

yt = secs_from_start()
test_time = string.format("%dm %ds", yt/60, yt%60)

print(string.format("Czas testu: %dmin %ds\n", yt/60, yt%60).." OK")

print("************ KONIEC. TEST OK **********")
-- koniec
return 0
--#######################################################################
--###########################	STOP	#################################
--#######################################################################