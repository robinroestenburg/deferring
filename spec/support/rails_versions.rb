def rails30
  ActiveRecord::VERSION::MAJOR == 3 &&
    ActiveRecord::VERSION::MINOR == 0
end

def rails32
  ActiveRecord::VERSION::MAJOR == 3 &&
    ActiveRecord::VERSION::MINOR == 2
end

def rails4
  ActiveRecord::VERSION::MAJOR == 4
end
