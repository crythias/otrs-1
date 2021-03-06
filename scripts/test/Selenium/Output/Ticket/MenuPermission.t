# --
# Copyright (C) 2001-2016 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;
use vars (qw($Self));

# get selenium object
my $Selenium = $Kernel::OM->Get('Kernel::System::UnitTest::Selenium');

$Selenium->RunTest(
    sub {

        # get needed objects
        my $SysConfigObject = $Kernel::OM->Get('Kernel::System::SysConfig');
        my $GroupObject     = $Kernel::OM->Get('Kernel::System::Group');
        my $DBObject        = $Kernel::OM->Get('Kernel::System::DB');
        my $TicketObject    = $Kernel::OM->Get('Kernel::System::Ticket');

        # get helper object
        $Kernel::OM->ObjectParamAdd(
            'Kernel::System::UnitTest::Helper' => {
                RestoreSystemConfiguration => 1,
            },
        );
        my $Helper = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

        # get needed variables
        my $RandomNumber = $Helper->GetRandomNumber();
        my $Success;

        # define group names - first will be added to the system, second doesn't exist
        my $TestGroupName        = 'exist:group:' . $RandomNumber;
        my $NoExistTestGroupName = 'no-exist:group:' . $RandomNumber;

        # add group
        my $TestGroupID = $GroupObject->GroupAdd(
            Name    => $TestGroupName,
            ValidID => 1,
            UserID  => 1,
        );
        $Self->True(
            $TestGroupID,
            "GroupID $TestGroupID is created",
        );

        # get original config for menu module 'Close'
        my %MenuModuleCloseSysConfig = $SysConfigObject->ConfigItemGet(
            Name => 'Ticket::Frontend::MenuModule###450-Close',
        );

        %MenuModuleCloseSysConfig = map { $_->{Key} => $_->{Content} }
            grep { defined $_->{Key} } @{ $MenuModuleCloseSysConfig{Setting}->[1]->{Hash}->[1]->{Item} };

        # create ticket
        my $TicketID = $TicketObject->TicketCreate(
            Title        => 'Selenium Ticket',
            Queue        => 'Raw',
            Lock         => 'unlock',
            Priority     => '3 normal',
            State        => 'new',
            CustomerID   => '123465',
            CustomerUser => 'SeleniumCustomer',
            OwnerID      => 1,
            UserID       => 1,
        );
        $Self->True(
            $TicketID,
            "TicketID $TicketID is created",
        );

        # create test user
        my $TestUserLogin = $Helper->TestUserCreate(
            Groups => [ 'admin', 'users', ],
        ) || die "Did not get test user";

        # get test user ID
        my $TestUserID = $Kernel::OM->Get('Kernel::System::User')->UserLookup(
            UserLogin => $TestUserLogin,
        );

        # add the group to the test user
        $Success = $GroupObject->PermissionGroupUserAdd(
            GID        => $TestGroupID,
            UID        => $TestUserID,
            Permission => {
                rw => 1,
            },
            UserID => 1,
        );
        $Self->True(
            $Success,
            "Test user '$TestUserLogin' update group permission for group '$TestGroupID'"
        );

        # login
        $Selenium->Login(
            Type     => 'Agent',
            User     => $TestUserLogin,
            Password => $TestUserLogin,
        );

        # get script alias
        my $ScriptAlias = $Kernel::OM->Get('Kernel::Config')->Get('ScriptAlias');

        my @Tests = (
            {
                Name           => "Menu module 'Close' exists",
                Group          => $TestGroupName,
                ExpectedResult => 1,
            },
            {
                Name           => "Menu module 'Close' doesn't exist",
                Group          => $NoExistTestGroupName,
                ExpectedResult => 0,
            }
        );

        for my $Test (@Tests) {

            # update config
            $SysConfigObject->ConfigItemUpdate(
                Valid => 1,
                Key   => 'Ticket::Frontend::MenuModule###450-Close',
                Value => {
                    %MenuModuleCloseSysConfig,
                    Group => 'rw:' . $Test->{Group},
                },
            );

            # let mod_perl / Apache2::Reload pick up the changed configuration
            sleep 1;

            # navigate to AgentTicketZoom screen of created test ticket
            $Selenium->VerifiedGet("${ScriptAlias}index.pl?Action=AgentTicketZoom;TicketID=$TicketID");

            # check if menu module 'Close' exists
            $Self->Is(
                $Selenium->execute_script("return \$('#nav-Close').length"),
                $Test->{ExpectedResult},
                $Test->{Name}
            );
        }

        # cleanup
        # delete group user relation
        $Success = $DBObject->Do(
            SQL => "DELETE FROM group_user WHERE user_id = $TestUserID AND group_id = $TestGroupID",
        );
        $Self->True(
            $Success,
            "Relation groupID '$TestGroupID' to userID '$TestUserID' is deleted"
        );

        # delete group
        $Success = $DBObject->Do(
            SQL => "DELETE FROM groups WHERE id = $TestGroupID",
        );
        $Self->True(
            $Success,
            "GroupID $TestGroupID is deleted",
        );

        # delete created test ticket
        $Success = $TicketObject->TicketDelete(
            TicketID => $TicketID,
            UserID   => 1,
        );
        $Self->True(
            $Success,
            "TicketID $TicketID is deleted"
        );

        # get cache object
        my $CacheObject = $Kernel::OM->Get('Kernel::System::Cache');

        # make sure cache is correct
        for my $Cache (qw( User Group Ticket )) {
            $CacheObject->CleanUp(
                Type => $Cache,
            );
        }
    }
);

1;
