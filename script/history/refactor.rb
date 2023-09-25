require "csv"

require_relative "../cg_api"

root_folder = ARGV.shift
after20210623 = ARGV.shift == "ok"

db = eval(IO.read("#{root_folder}/script/history/db.hash")) rescue {}
db_dates = eval(IO.read("#{root_folder}/script/history/db_dates.hash")) rescue {}

golfs = Hash.new{|h, k| h[k] = [] }
golfs_count = Hash.new(0)
golfs_header = {}

def update_db(db, key)
  unless db[key]
    db[key] = post(URI_PLAYER, [key]).values_at("countryId", "avatar")
    # write every time 
    IO.write("#{root_folder}/script/history/db.hash", db.to_s)
  end
end

# League,Score,UserID,AgentID,Lang,Pseudo,#multi|count=684|time=2023-02-07T00:30:11
# after 2021-06-23
# Comp.,Score,UserID,Lang,Pseudo,#optim|count=591|time=2023-02-07T00:30:28
# Comp.,Score,UserID,Pseudo,#golf|count=323|time=2023-02-07T00:30:35
# before 2021-06-23
# Score,UserID,Lang,Pseudo,#optim|count=591|time=2023-02-07T00:30:28
# Score,UserID,Pseudo,#golf|count=323|time=2023-02-07T00:30:35
Dir::glob("puzzle/**/*.csv").each do |x|
  header, *csv = CSV.parse(IO.read(x))
  header[-1].sub!(/nonzero=\d+\|/,'')
  # fix count if possible
  header[-1].sub!(/count=\K\d{1,3}(?=\|)/){csv.size}
  header[-1].sub!(/count=\K\d+/){csv.size} if csv.size < 1000
  count, *datetime = header[-1].scan(/\d+/)
  timestamp = Time.new(*datetime, 0).to_i * 1000 rescue (p header and raise)
  case x
  when /golf\/(.*)\/(.*)\.csv$/
    header = HEADER_OPTIM + [header[-1]]
    golfs_count[$1] += count.to_i
    golfs_header[$1] ||= header[-1]
    score = 100
    best = 0
    csv.each do |row|
      unless after20210623
        score -= 1 if best > row[0].to_f
        best = row[0].to_f
        row.unshift(score)
      end
      row[2, 0] = $2, nil
      update_db(db, row[4])
      row[-1, 1] = [*db[row[4]], nil, nil, nil][..2]
      user = db_dates[row[4]] ||= {}
      puzzle = user[$1] ||= {}
      lang = puzzle[row[2]] ||= {}
      if lang["score"] != row[1]
        lang["score"] = row[1]
        lang["timestamp"] = timestamp
      end
      row[3] = lang["timestamp"]
      golfs[$1] << row
    end
    csv.sort_by!{|row| [-row[0].to_f, row[1].to_f, row[3].to_i, row[2], row[5].to_s] }
    content = csv.reduce(header.to_csv) do |acc, row|
      acc << row.to_csv
    end
  when /optim\/(.*)\.csv$/
    header = HEADER_OPTIM + [header[-1]]
    score = 100
    i = after20210623 ? 1 : 0
    r1, r2 = csv.each_cons(2).find{|a,b| a[i] != b[i] }
    up = r1[i].to_f > r2[i].to_f
    best = up ? Float::INFINITY : -Float::INFINITY
    csv.each do |row|
      unless after20210623
        score -= 1 if (up ? best < row[0].to_f : best > row[0].to_f)
        best = row[0].to_f
        row.unshift(score)
      end
      row[2, 2] = row[3], nil, row[2]
      update_db(db, row[4])
      row[-1, 1] = [*db[row[4]], nil, nil, nil][..2]
      user = db_dates[row[4]] ||= {}
      puzzle = user[$1] ||= {}
      lang = puzzle[row[2]] ||= {}
      if lang["score"] != row[1]
        lang["score"] = row[1]
        lang["timestamp"] = timestamp
      end
      row[3] = lang["timestamp"]
    end
    csv.sort_by!{|row| [-row[0].to_f, up ? -row[1].to_f : row[1].to_f, row[3].to_i, row[2], row[5].to_s] }
    content = csv.reduce(header.to_csv) do |acc, row|
      acc << row.to_csv
    end
  else
    header = HEADER_MULTI + [header[-1]]
    content = csv.reduce(header.to_csv) do |acc, row|
      row[2, 3] = row[4], nil, row[3], row[2]
      update_db(db, row[5])
      row[-1, 1] = [*db[row[5]], nil, nil, nil][..2]
      # can't track timestamp for multi? :(
      acc << row.to_csv
    end
  end
  IO.write(x, content)
end

golfs.each do |golf, csv|
  header = golfs_header[golf].sub(/count=\K\d+/){golfs_count[golf]}
  # fallback to language+pseudo because only approximation for timestamp
  content = csv.sort_by!{|row| [-row[0].to_f, row[1].to_f, row[3].to_i, row[2], row[5].to_s] }.first(1000).reduce((HEADER_OPTIM + [header]).to_csv) do |acc, row|
    acc << row.to_csv
  end
  IO.write("puzzle/golf/#{golf}/all.csv", content)
end

IO.write("#{root_folder}/script/history/db_dates.hash", db_dates.to_s)