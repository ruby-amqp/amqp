$:.unshift File.dirname(__FILE__) + '/../lib'
require 'mq'

EM.run{

  def log *args
    p args
  end

  # MQ.logging = true

  if ARGV[0] == 'worker'

    class Fixnum
      def prime?
        ('1' * self) !~ /^1?$|^(11+?)\1+$/
      end
    end

    MQ.queue('prime checker').subscribe{ |info, num|
      log 'prime checker', :prime?, num, :pid => Process.pid
      if Integer(num).prime?
        MQ.direct.publish(num, :key => info.reply_to, :reply_to => Process.pid)
      end
    }

  else

    # define the prime checker queue so messages we send
    # before starting workers are not lost
    MQ.queue('prime checker')

    MQ.queue('prime collector').subscribe{ |info, prime|
      log 'prime collector', :received, prime, :from_pid => info.reply_to
      (@primes ||= []) << Integer(prime)
    }

    i = 1
    EM.add_periodic_timer(0.01) do
      MQ.direct.publish(i.to_s, :reply_to => 'prime collector', :key => 'prime checker')
      EM.stop_event_loop if i == 50
      i += 1
    end

  end
}

__END__

$ ruby primes.rb worker &
[1] 4787

$ ruby primes.rb worker &
[2] 4791

$ ruby primes.rb worker &
[3] 4794

$ ruby primes.rb worker &
[4] 4797

$ ruby primes.rb 
["prime checker", :prime?, "1", {:pid=>4787}]
["prime checker", :prime?, "2", {:pid=>4791}]
["prime collector", :received, "2", {:from_pid=>"4791"}]
["prime checker", :prime?, "3", {:pid=>4794}]
["prime collector", :received, "3", {:from_pid=>"4794"}]
["prime checker", :prime?, "4", {:pid=>4797}]
["prime checker", :prime?, "5", {:pid=>4787}]
["prime collector", :received, "5", {:from_pid=>"4787"}]
["prime checker", :prime?, "6", {:pid=>4791}]
["prime checker", :prime?, "7", {:pid=>4794}]
["prime collector", :received, "7", {:from_pid=>"4794"}]
["prime checker", :prime?, "8", {:pid=>4797}]
["prime checker", :prime?, "9", {:pid=>4787}]
["prime checker", :prime?, "10", {:pid=>4791}]
["prime checker", :prime?, "11", {:pid=>4794}]
["prime collector", :received, "11", {:from_pid=>"4794"}]
["prime checker", :prime?, "12", {:pid=>4797}]
["prime checker", :prime?, "13", {:pid=>4787}]
["prime collector", :received, "13", {:from_pid=>"4787"}]
["prime checker", :prime?, "14", {:pid=>4791}]
["prime checker", :prime?, "15", {:pid=>4794}]
["prime checker", :prime?, "16", {:pid=>4797}]
["prime checker", :prime?, "17", {:pid=>4787}]
["prime collector", :received, "17", {:from_pid=>"4787"}]
["prime checker", :prime?, "18", {:pid=>4791}]
["prime checker", :prime?, "19", {:pid=>4794}]
["prime collector", :received, "19", {:from_pid=>"4794"}]
["prime checker", :prime?, "20", {:pid=>4797}]
["prime checker", :prime?, "21", {:pid=>4787}]
["prime checker", :prime?, "22", {:pid=>4791}]
["prime checker", :prime?, "23", {:pid=>4794}]
["prime collector", :received, "23", {:from_pid=>"4794"}]
["prime checker", :prime?, "24", {:pid=>4797}]
["prime checker", :prime?, "25", {:pid=>4787}]
["prime checker", :prime?, "26", {:pid=>4791}]
["prime checker", :prime?, "27", {:pid=>4794}]
["prime checker", :prime?, "28", {:pid=>4797}]
["prime checker", :prime?, "29", {:pid=>4787}]
["prime collector", :received, "29", {:from_pid=>"4787"}]
["prime checker", :prime?, "30", {:pid=>4791}]
["prime checker", :prime?, "31", {:pid=>4794}]
["prime collector", :received, "31", {:from_pid=>"4794"}]
["prime checker", :prime?, "32", {:pid=>4797}]
["prime checker", :prime?, "33", {:pid=>4787}]
["prime checker", :prime?, "34", {:pid=>4791}]
["prime checker", :prime?, "35", {:pid=>4794}]
["prime checker", :prime?, "36", {:pid=>4797}]
["prime checker", :prime?, "37", {:pid=>4787}]
["prime collector", :received, "37", {:from_pid=>"4787"}]
["prime checker", :prime?, "38", {:pid=>4791}]
["prime checker", :prime?, "39", {:pid=>4794}]
["prime checker", :prime?, "40", {:pid=>4797}]
["prime checker", :prime?, "41", {:pid=>4787}]
["prime collector", :received, "41", {:from_pid=>"4787"}]
["prime checker", :prime?, "42", {:pid=>4791}]
["prime checker", :prime?, "43", {:pid=>4794}]
["prime collector", :received, "43", {:from_pid=>"4794"}]
["prime checker", :prime?, "44", {:pid=>4797}]
["prime checker", :prime?, "45", {:pid=>4787}]
["prime checker", :prime?, "46", {:pid=>4791}]
["prime checker", :prime?, "47", {:pid=>4794}]
["prime collector", :received, "47", {:from_pid=>"4794"}]
["prime checker", :prime?, "48", {:pid=>4797}]
["prime checker", :prime?, "49", {:pid=>4787}]
["prime checker", :prime?, "50", {:pid=>4791}]
