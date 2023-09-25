# frozen_string_literal: true

SimpleCov.start do
   coverage_dir '.coverage'
   enable_coverage :branch

   root __dir__
end
