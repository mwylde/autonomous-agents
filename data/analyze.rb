def plot p
  f = File.open(p).read
  a = f.split("\n").collect{|x| x.match(/\((.+?), (.+?)\) \((.+?), (.+?)\) (.+?) (.+)/)[1..-1]}

  a.collect{|aa|
    x1, y1, x2, y2, t, s = aa
    [Math.sqrt((x1.to_f-x2.to_f)**2 + (y1.to_f-y2.to_f)**2), t.to_f, s == "succeeded"]
  }
end

Dir.glob("*map.txt").each{|s|
  File.open("#{s}.out.txt", "w+"){|f|
    f.write("distance, time, success\n")
    p = plot(s)
    puts s + " " + (p.reject{|x| !x[-1]}.size / p.size.to_f).round(3).to_s
    f.write p.reject{|x| !x[-1]}.collect{|x| x.join(",")}.join("\n")
  }
}
