
Dir::glob("site/events/*").unshift(nil).push(nil).each_cons(3) do |a, b, c|
  IO.write(b,
    IO.read(b).sub(/(<a href="\/events\/)[\d-]+?(\.html"\>prev day<\/a>)/, a ? "\\1#{a[/[\d-]+/]}\\2" : "")
              .sub(/(<a href="\/events\/)[\d-]+?(\.html"\>next day<\/a>)/, c ? "\\1#{c[/[\d-]+/]}\\2" : "")
  )
end