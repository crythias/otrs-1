#!/usr/bin/perl
# --
# bin/otrs.GetConfig.pl - get OTRS config vars
# Copyright (C) 2001-2014 OTRS AG, http://otrs.com/
# --
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU AFFERO General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301 USA
# or see http://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;

use File::Basename;
use FindBin qw($RealBin);
use lib dirname($RealBin);
use lib dirname($RealBin) . '/Kernel/cpan-lib';
use lib dirname($RealBin) . '/Custom';

use Kernel::System::ObjectManager;

# common objects
local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Kernel::System::Log' => {
        LogPrefix => 'OTRS-otrs.GetConfig',
    },
);

# print wanted var
my $Key = shift || '';
if ($Key) {
    chomp $Key;
    if ( ref( $Kernel::OM->Get('Kernel::Config')->{$Key} ) eq 'ARRAY' ) {
        for ( @{ $Kernel::OM->Get('Kernel::Config')->{$Key} } ) {
            print "$_;";
        }
        print "\n";
    }
    elsif ( ref( $Kernel::OM->Get('Kernel::Config')->{$Key} ) eq 'HASH' ) {
        for my $SubKey ( sort keys %{ $Kernel::OM->Get('Kernel::Config')->{$Key} } ) {
            print "$SubKey=$Kernel::OM->Get('Kernel::Config')->{$Key}->{$SubKey};";
        }
        print "\n";
    }
    else {
        print $Kernel::OM->Get('Kernel::Config')->{$Key} . "\n";
    }
}
else {

    # print all vars
    for ( sort keys %{ $Kernel::OM->Get('Kernel::Config') } ) {
        print $_. ":";
        if ( ref( $Kernel::OM->Get('Kernel::Config')->{$_} ) eq 'ARRAY' ) {
            for ( @{ $Kernel::OM->Get('Kernel::Config')->{$_} } ) {
                print "$_;";
            }
            print "\n";
        }
        elsif ( ref( $Kernel::OM->Get('Kernel::Config')->{$_} ) eq 'HASH' ) {
            for my $Key ( sort keys %{ $Kernel::OM->Get('Kernel::Config')->{$_} } ) {
                print "$Key=$Kernel::OM->Get('Kernel::Config')->{$_}->{$Key};";
            }
            print "\n";
        }
        else {
            print $Kernel::OM->Get('Kernel::Config')->{$_} . "\n";
        }
    }
}
