
THREAD_CNT = 10


$processes = []

# nejaky konstanty
T_STATUS_ACTIVE = 1
T_STATUS_INACTIVE = 2
T_TYPE_NORM = 1
T_TYPE_COOR = 2


# stopnuti threadu na interrupt
trap("SIGINT") do
    puts "\nSIGINT - terminating threads"
    1.upto(THREAD_CNT) do |i|
        $processes[i].terminate!
    end
end

#struktura bufferu
$b= {:type => "typ zpravy", :msg => "zprava"}



#
# ziskani dalsiho procesu v kruhu
def next_pid(tid)
    if(tid == THREAD_CNT)
        return 1
    else
        return tid+1
    end
end



#
# poslani zpravy ELECTION dalsimu procesu
def send_el_msg(pid, msg)
    buffer = $b.clone
    buffer[:type] = "ELECTION"
    buffer[:msg] = msg

    # najdu dalsi aktivni proces
    succ = next_pid(pid)
    while($processes[succ][:active] != true)
        succ = next_pid(succ)
    end

    $processes[succ][:buffer] = buffer
end



#
# poslani zpravy COORDINATOR dalsimu procesu
def send_coor_msg(pid, msg)
    buffer = $b.clone
    buffer[:type] = "COORDINATOR"
    buffer[:msg] = msg

    # najdu dalsi aktivni proces
    succ = next_pid(pid)
    while($processes[succ][:active] != true)
        succ = next_pid(succ)
    end

    $processes[succ][:buffer] = buffer
end



1.upto(THREAD_CNT) do |i|
    $processes[i] = Thread.new(i) do
        #current thread - zkratka
        ct = Thread.current

        ct[:buffer] = nil
        ct[:id] = i
        ct[:active] = true
        ct[:coor] = 1

        # inicializace - prvni vlakno je koordinator
        ct[:type] = (i == 1 ? T_TYPE_COOR : T_TYPE_NORM )


        # nekonecna smycka pro kazde vlakno
        while 1
            sleep(0.2)

            # v pripade neprazdneho bufferu se provedou prislusne akce,
            # jinak se jede dal - proces si dela svoji praci
            if not ct[:buffer].nil?
                buffer = ct[:buffer]

                case buffer[:type]
                    # proces prodpoklada, ze doslo k vypadku koordinatora
                    # posila zpravu dalsimu v poradi
                    when "SUSPECT"
                        puts ct[:id].to_s+" prijal SUSPECT"
                        list = [ct[:id]]
                        send_el_msg(ct[:id], list)




                    # proces dostal zpravu o volbe koordinatora
                    # pokud prvni PID odpovida jeho - jedna se o zpravu, ktera obesla kruh
                    # zpracuje vysledek a rozesle oznameni o novem koordinatorovi
                    when "ELECTION"
                        puts ct[:id].to_s+" prijal ELECTION\tbuffer: "+buffer[:msg].join(", ")

                        # zprava obehla dokola - prvni v poli pid je shodne s pid aktualniho procesu
                        if(buffer[:msg][0] == ct[:id])
                            puts "zprava obehla kruh "
                            max = buffer[:msg].inject(buffer[:msg][0]) {|max, item| item > max ? item : max }

                            # odeslani zpravy s novym koordinatorem
                            puts "novy koordinator s pid:"+max.to_s
                            send_coor_msg(ct[:id], {:new_coor => max, :active => buffer[:msg]})

                        # jinak posilam dal zpravu a pridam moje id
                        else
                            send_el_msg(ct[:id], buffer[:msg].push(ct[:id]))
                        end

                    # proces dostal zpravu o nove zvolenem koordinatorovi
                    # ulozi si jeho hodnotu
                    when "COORDINATOR"
                        puts ct[:id].to_s+" prijal COORDINATOR\tnovy koordinator:"+buffer[:msg][:new_coor].to_s
                        ct[:coor] = buffer[:msg][:new_coor]                        

                        # pokud se zprava vratila, pokracuje dal v zevleni
                        # jinak posila dal
                        if(buffer[:msg][:active][0] != ct[:id])
                            send_coor_msg(ct[:id], buffer[:msg])
                        else
                            puts "konec volby - COORDINATOR obehl kruh"
                        end
                end # case buffer type

                #po precteni nuluju buffer a provadim normalni cinnost vlakna - tzn. zevlovani
                ct[:buffer] = nil
            end
        end

        puts "buffer: "+Thread.current[:buffer].to_s
    end
end





# po nejake dobe nastava vypadek koordinatora pro thread 3
sleep(1)

$processes[5][:active] = false
$processes[10][:active] = false
$processes[1][:active] = false

newb = $b.clone
newb[:type] = "SUSPECT"
newb[:msg] = "true"
$processes[3][:buffer] = newb 


# po vykonani predchozi volby se opet aktivuji nektere procesy a posle se zprava
# o podezreni vypadku procesu cislo 4
sleep(5)
$processes[10][:active] = true
$processes[1][:active] = true
newb = $b.clone
newb[:type] = "SUSPECT"
newb[:msg] = "true"
$processes[4][:buffer] = newb 



# pockani na vsechny thready v hlavnim threadu
# program se neukonci
1.upto(THREAD_CNT) do |i|
    $processes[i].join
end




