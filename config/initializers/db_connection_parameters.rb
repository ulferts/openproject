#-- encoding: UTF-8
#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) 2012-2020 the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2017 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See docs/COPYRIGHT.rdoc for more details.
#++

# We need to ensure that we operate on a well-known TRANSACTION ISOLATION LEVEL
# Therefore we want to ensure that the isolation level is consistent on a session basis.
# We chose READ COMMITTED as our expected default isolation level, this is the default of
# PostgreSQL.
module DbConnectionParameters
  module ConnectionPoolPatch
    def new_connection
      connection = super
      DbConnectionParameters.set_connection_parameters(connection)
      connection
    end
  end

  def self.set_connection_parameters(connection)
    DbConnectionParameters.set_connection_isolation_level connection
    DbConnectionParameters.set_interval_style connection
  end

  def self.set_connection_isolation_level(connection)
    connection.execute("SET SESSION CHARACTERISTICS AS TRANSACTION ISOLATION LEVEL READ COMMITTED")
  end

  def self.set_interval_style(connection)
    connection.execute("SET IntervalStyle = 'iso_8601';")
  end
end

ActiveRecord::ConnectionAdapters::ConnectionPool.prepend(DbConnectionParameters::ConnectionPoolPatch)

# in case the existing connection was created before our patch
# N.B.: this assumes that our process only has this single thread, which is at least true today...
DbConnectionParameters.set_connection_parameters ActiveRecord::Base.connection
