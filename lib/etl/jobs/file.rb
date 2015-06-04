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

require 'etl/jobs/base.rb'

module ETL::Job

  class File < Base

    # Root directory under which all file-based data feeds will be placed
    # Directory structure is:
    # OUTPUT_ROOT/FEED_NAME/BATCH.(csv|json|xml)
    def output_root
      "/var/tmp/etl_test_output"
    end

    # Output file name for this batch
    def output_file(batch)
      [
        output_root,
        feed_name,
        batch.to_s() + "." + output_extension
      ].join("/")
    end
  end
end