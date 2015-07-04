###############################################################################
# Copyright (C) 2015 Chuck Smith
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
# 
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
###############################################################################

require 'rails_helper'

require 'etl/core'

# Test reading and writing basic CSV file
class TestCsvCreate1 < ETL::Job::CSV
  def initialize(reader)
    super
    @feed_name = "test_1"

    define_schema do |s|
      s.date("day")
      s.string("condition")
      s.int("value_int")
      s.numeric("value_num", 10, 1)
      s.float("value_float")
    end
  end
end


# Test reading in pipe-separated file and outputting @ separated
class TestCsvCreate2 < ETL::Job::CSV
  def initialize(reader)
    super
    @feed_name = "test_2"
    define_schema do |s|
      s.date("day")
      s.string("condition")
      s.int("value_int")
      s.numeric("value_num", 10, 1)
      s.float("value_float")
    end

    @load_strategy = :insert_table
  end

  def csv_output_options
    return super.merge({col_sep: '@'})
  end
end



RSpec.describe Job, :type => :job do

  it "csv - overwrite" do

    # remove old file
    outfile = "/var/tmp/etl_test_output/test_1/2015-03-31.csv"
    File.delete(outfile) if File.exist?(outfile)
    expect(File.exist?(outfile)).to be false

    input = ETL::Input::CSV.new("#{Rails.root}/spec/data/simple1.csv")
    input.headers_map = {
        "attribute" => "condition", 
        "value_numeric" => "value_num"
    }
    batch = ETL::Job::DateBatch.new(2015, 3, 31)

    job = TestCsvCreate1.new(input)
    job.load_strategy = :insert_table
    jr = job.run(batch)
    expect(job.output_file).to eq(outfile)
    expect(jr.status).to eq(:success)
    expect(jr.num_rows_success).to eq(3)
    expect(jr.num_rows_error).to eq(0)
    expect(jr.message).to include(outfile)
    expect(File.exist?(outfile)).to be true
    expect(input.rows_processed).to eq(3)

    contents = IO.read(outfile)
    expect_contents = <<END
day,condition,value_int,value_num,value_float
2015-04-01,rain,0,12.3,59.3899
2015-04-02,snow,1,13.1,60.2934
2015-04-03,sun,-1,0.4,-12.83
END
    expect(contents).to eq(expect_contents)

    # run a second time
    job = TestCsvCreate1.new(input)
    job.load_strategy = :insert_table
    jr = job.run(batch)
    expect(job.output_file).to eq(outfile)
    expect(jr.status).to eq(:success)
    expect(jr.num_rows_success).to eq(3)
    expect(jr.num_rows_error).to eq(0)
    expect(jr.message).to include(outfile)
    expect(File.exist?(outfile)).to be true
    expect(input.rows_processed).to eq(3)

    contents = IO.read(outfile)
    expect_contents = <<END
day,condition,value_int,value_num,value_float
2015-04-01,rain,0,12.3,59.3899
2015-04-02,snow,1,13.1,60.2934
2015-04-03,sun,-1,0.4,-12.83
END
    expect(contents).to eq(expect_contents)

  end


  it "csv - append" do

    # remove old file
    outfile = "/var/tmp/etl_test_output/test_1/2015-03-31.csv"
    File.delete(outfile) if File.exist?(outfile)
    expect(File.exist?(outfile)).to be false

    input = ETL::Input::CSV.new("#{Rails.root}/spec/data/simple1.csv")
    input.headers_map = {
        "attribute" => "condition", 
        "value_numeric" => "value_num"
    }
    batch = ETL::Job::DateBatch.new(2015, 3, 31)

    job = TestCsvCreate1.new(input)
    job.load_strategy = :insert_append
    jr = job.run(batch)

    expect(job.output_file).to eq(outfile)
    expect(jr.status).to eq(:success)
    expect(jr.num_rows_success).to eq(3)
    expect(jr.num_rows_error).to eq(0)
    expect(jr.message).to include(outfile)
    expect(File.exist?(outfile)).to be true
    expect(input.rows_processed).to eq(3)

    contents = IO.read(outfile)
    expect_contents = <<END
day,condition,value_int,value_num,value_float
2015-04-01,rain,0,12.3,59.3899
2015-04-02,snow,1,13.1,60.2934
2015-04-03,sun,-1,0.4,-12.83
END
    expect(contents).to eq(expect_contents)

    # run a second time
    job = TestCsvCreate1.new(input)
    job.load_strategy = :insert_append
    jr = job.run(batch)
    expect(job.output_file).to eq(outfile)
    expect(jr.status).to eq(:success)
    expect(jr.num_rows_success).to eq(3)
    expect(jr.num_rows_error).to eq(0)
    expect(jr.message).to include(outfile)
    expect(File.exist?(outfile)).to be true
    expect(input.rows_processed).to eq(3)

    contents = IO.read(outfile)
    expect_contents = <<END
day,condition,value_int,value_num,value_float
2015-04-01,rain,0,12.3,59.3899
2015-04-02,snow,1,13.1,60.2934
2015-04-03,sun,-1,0.4,-12.83
2015-04-01,rain,0,12.3,59.3899
2015-04-02,snow,1,13.1,60.2934
2015-04-03,sun,-1,0.4,-12.83
END
    expect(contents).to eq(expect_contents)

  end


  it "psv - overwrite" do

    # remove old file
    outfile = "/var/tmp/etl_test_output/test_2/2015-03-31.csv"
    File.delete(outfile) if File.exist?(outfile)
    expect(File.exist?(outfile)).to be false
    # file does not have headers

    input = ETL::Input::CSV.new("#{Rails.root}/spec/data/simple1.psv",
      {headers: false, col_sep: '|'})
    input.headers = %w{day condition value_int value_num value_float}
    job = TestCsvCreate2.new(input)
    batch = ETL::Job::DateBatch.new(2015, 3, 31)

    jr = job.run(batch)

    expect(input.rows_processed).to eq(3)
    expect(job.output_file).to eq(outfile)
    expect(jr.status).to eq(:success)
    expect(jr.num_rows_success).to eq(3)
    expect(jr.num_rows_error).to eq(0)
    expect(jr.message).to include(outfile)
    expect(File.exist?(outfile)).to be true

    contents = IO.read(outfile)
    expect_contents = <<END
day@condition@value_int@value_num@value_float
2015-04-01@rain@0@12.3@59.3899
2015-04-02@snow@1@13.1@60.2934
2015-04-03@sun@-1@0.4@-12.83
END
    expect(contents).to eq(expect_contents)
  end
end
