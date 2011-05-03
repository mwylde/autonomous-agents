def plot p
  f = File.open(p).read
  a = f.split("\n").collect{|x| x.match(/\((.+?), (.+?)\) \((.+?), (.+?)\) (.+?) (.+)/)[1..-1]}

  a.collect{|aa|
    x1, y1, x2, y2, t, s = aa
    [Math.sqrt((x1.to_f-x2.to_f)**2 + (y1.to_f-y2.to_f)**2), t.to_f, s == "succeeded"]
  }
end

Dir.glob("*sc.txt").each{|s|
  File.open("#{s}.out.txt", "w+"){|f|
    f.write("distance, time, success\n")
    f.write plot(s).reject{|x| !x[-1]}.collect{|x| x.join(",")}.join("\n")
  }
}
