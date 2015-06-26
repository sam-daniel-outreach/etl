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

# Test loading into postgres
class TestPgCreate1 < ETL::Job::PostgreSQL
  def initialize(input, conn)
    super(input, conn)
    @feed_name = "test_1"

    define_schema do |s|
      s.date("day")
      s.string("condition")
      s.int("value_int")
      s.numeric("value_num", 10, 1)
      s.float("value_float")
    end

    load_strategy = :insert_append
  end
end



class TestPgLoad1 < ETL::Job::PostgreSQL
  def initialize(input, conn, table_name)
    super(input, conn)
    @feed_name = table_name
    define_schema do |s|
      s.date("day")
      s.int("id")
      s.int("value")
    end
  end
end


RSpec.describe Job, :type => :job do

  it "postgres - insert from csv" do
    dbconfig = Rails.configuration.database_configuration[Rails.env]
    conn = PGconn.open(
        :dbname => dbconfig["database"],
        :user => dbconfig["username"],
        :password => dbconfig["password"],
        :host => dbconfig["host"]
        )

    # Create destination table
    sql = <<SQL
drop table if exists test_1;
create table test_1 (
  day timestamp, 
  condition varchar, 
  value_int int, 
  value_num numeric(10, 1), 
  value_float float);
SQL
    conn.exec(sql)


    batch = ETL::Job::DateBatch.new(2015, 3, 31)
    input = ETL::Input::CSV.new("#{Rails.root}/spec/data/simple1.csv")
    input.headers_map = {
        "attribute" => "condition", 
        "value_numeric" => "value_num"
    }
    job = TestPgCreate1.new(input, conn)
    job.row_batch_size = 2 # test batching of rows loaded to tmp

    jr = job.run(batch)

    expect(input.rows_processed).to eq(3)
    expect(jr.status).to eq(:success)
    expect(jr.num_rows_success).to eq(3)
    expect(jr.num_rows_error).to eq(0)

    result = conn.exec("select * from test_1 order by day asc")
    v = result.values
    expect(v.length).to eq(3)
    expect(v[0][0]).to eq('2015-04-01 00:00:00')
    expect(v[1][0]).to eq('2015-04-02 00:00:00')
    expect(v[2][0]).to eq('2015-04-03 00:00:00')
    expect(v[0][1]).to eq('rain')
    expect(v[1][1]).to eq('snow')
    expect(v[2][1]).to eq('sun')
  end




  it "postgres - insert append" do
    table_name = "test_2"
    dbconfig = Rails.configuration.database_configuration[Rails.env]
    conn = PGconn.open(
        :dbname => dbconfig["database"],
        :user => dbconfig["username"],
        :password => dbconfig["password"],
        :host => dbconfig["host"]
        )

    # Create destination table
    sql = <<SQL
drop table if exists #{table_name};
create table #{table_name} (
  day timestamp, 
  id int,
  value int
  );
SQL
    conn.exec(sql)


    batch = ETL::Job::DateBatch.new(2015, 4, 3)
    data = [
      { "day" => "2015-04-01", "id" => 10, "value" => 1},
      { "day" => "2015-04-02", "id" => 11, "value" => 2},
      { "day" => "2015-04-03", "id" => 12, "value" => 3},
    ]
    input = ETL::Input::Array.new(data)
    job = TestPgLoad1.new(input, conn, table_name)
    job.load_strategy = :insert_append
    jr = job.run(batch)
    expect(input.rows_processed).to eq(3)
    expect(jr.status).to eq(:success)
    expect(jr.num_rows_success).to eq(3)
    expect(jr.num_rows_error).to eq(0)

    data = [
      { "day" => "2015-04-02", "id" => 11, "value" => 4},
      { "day" => "2015-04-02", "id" => 13, "value" => 5},
    ]
    input = ETL::Input::Array.new(data)
    job = TestPgLoad1.new(input, conn, table_name)
    job.load_strategy = :insert_append
    jr = job.run(batch)
    expect(input.rows_processed).to eq(2)
    expect(jr.status).to eq(:success)
    expect(jr.num_rows_success).to eq(2)
    expect(jr.num_rows_error).to eq(0)



    result = conn.exec(<<SQL
select day, id, value 
from #{table_name} 
order by day, id, value;
SQL
    )

    exp_values = [
      ["2015-04-01 00:00:00", "10", "1"],
      ["2015-04-02 00:00:00", "11", "2"],
      ["2015-04-02 00:00:00", "11", "4"],
      ["2015-04-02 00:00:00", "13", "5"],
      ["2015-04-03 00:00:00", "12", "3"],
    ]

    compare_pg_results(exp_values, result.values)
  end


  # helper function for comparing expected and actual results from PG
  def compare_pg_results(e, a)
    expect(a.length).to eq(e.length)
    (0...e.length).each do |i|
      expect(a[i].length).to eq(e[i].length)
      (0...e[i].length).each do |j|
        expect(a[i][j]).to eq(e[i][j])
      end
    end
  end
end