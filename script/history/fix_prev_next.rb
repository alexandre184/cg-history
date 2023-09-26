
Dir::glob("docs/events/*").unshift(nil).push(nil).each_cons(3) do |a, b, c|
  IO.write(b,
    IO.read(b).sub(/(<a href="\/events\/)([\d-]+?)\.html".*?(>prev day<\/a>)/){ d = $3; "#$1#{a ? a[/[\d-]+/] : $2}.html\"#{a ? "" : 'style="display:none"'}#{d}" }
              .sub(/(<a href="\/events\/)([\d-]+?)\.html".*?(>next day<\/a>)/){ d = $3; "#$1#{c ? c[/[\d-]+/] : $2}.html\"#{c ? "" : 'style="display:none"'}#{d}" }
  )
end