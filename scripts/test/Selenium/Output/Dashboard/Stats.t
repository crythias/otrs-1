# --
# Copyright (C) 2001-2015 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

# TODO temporarily disabled. PhantomJS throws errors with the version of D3/NVD3 that OTRS 4 uses.
# Re-enable this test after an upgrade.
return 1;

# get selenium object
my $Selenium = $Kernel::OM->Get('Kernel::System::UnitTest::Selenium');

$Selenium->RunTest(
    sub {

        # get helper object
        $Kernel::OM->ObjectParamAdd(
            'Kernel::System::UnitTest::Helper' => {
                RestoreSystemConfiguration => 1,
            },
        );
        my $Helper = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

        # get sysconfig object
        my $SysConfigObject = $Kernel::OM->Get('Kernel::System::SysConfig');

        # disable all dashboard plugins
        my $Config = $Kernel::OM->Get('Kernel::Config')->Get('DashboardBackend');
        $SysConfigObject->ConfigItemUpdate(
            Valid => 0,
            Key   => 'DashboardBackend',
            Value => \%$Config,
        );

        # reset TicketQueueOverview dashboard sysconfig so dashboard can be loaded
        $SysConfigObject->ConfigItemReset(
            Name => 'DashboardBackend###0270-TicketQueueOverview',
        );

        # create test user and login
        my $TestUserLogin = $Helper->TestUserCreate(
            Groups => [ 'admin', 'users', 'stats' ],
        ) || die "Did not get test user";

        $Selenium->Login(
            Type     => 'Agent',
            User     => $TestUserLogin,
            Password => $TestUserLogin,
        );

        # get user object
        my $UserObject = $Kernel::OM->Get('Kernel::System::User');

        # get test user ID
        my $TestUserID = $UserObject->UserLookup(
            UserLogin => $TestUserLogin,
        );

        # get stats object
        $Kernel::OM->ObjectParamAdd(
            'Kernel::System::Stats' => {
                UserID => $TestUserID,
            },
        );
        my $StatsObject = $Kernel::OM->Get('Kernel::System::Stats');

        # export stat 'Overview about all tickets in the system' - StatID 7
        my $ExportFile = $StatsObject->Export( StatID => 7 );
        $Self->True(
            $ExportFile->{Content},
            'Successfully exported StatID - 7',
        );

        # import the exported stat
        my $TestStatID = $StatsObject->Import( Content => $ExportFile->{Content} );
        $Self->True(
            $TestStatID,
            'Successfully imported StatID - 7',
        );

        # update test stats name and show as dashboard widget
        my $TestStatsName = "SeleniumStats" . int( rand(1000) );
        my $Update        = $StatsObject->StatsUpdate(
            StatID => $TestStatID,
            Hash   => {
                Title                 => $TestStatsName,
                ShowAsDashboardWidget => '1',
            },
        );
        $Self->True(
            $Update,
            "Stats updated ID - $TestStatID",
        );

        # refresh dashboard screen
        $Selenium->refresh();

        # enable stats widget on dashboard
        my $StatsInSettings = "Settings10" . $TestStatID . "-Stats";
        $Selenium->find_element( ".SettingsWidget .Header a", "css" )->click();
        $Selenium->WaitFor( JavaScript => "return \$('.SettingsWidget.Expanded').length;" );

        $Selenium->find_element( "#$StatsInSettings",      'css' )->click();
        $Selenium->find_element( ".SettingsWidget button", 'css' )->click();

        my $CommandObject = $Kernel::OM->Get('Kernel::System::Console::Command::Maint::Stats::Dashboard::Generate');
        my $ExitCode      = $CommandObject->Execute();
        $Selenium->refresh();

        # check dashboard test stats data
        my $TestName = 'Statistic: ' . $TestStatsName;
        $Self->True(
            index( $Selenium->get_page_source(), $TestName ) > -1,
            "Stats dashboard widget name found - $TestName",
        );
        for my $Test (qw( Grouped Stacked Raw Postmaster Misc Junk )) {

            # check for legend data in dashboard test stats
            $Self->True(
                index( $Selenium->get_page_source(), $Test ) > -1,
                "Stats dashboard legend data found - $Test",
            );
        }

        # delete test stats
        $Self->True(
            $StatsObject->StatsDelete( StatID => $TestStatID ),
            "Delete StatID - $TestStatID",
        );

        # make sure cache is correct
        for my $Cache (qw( Stats Dashboard DashboardQueueOverview )) {
            $Kernel::OM->Get('Kernel::System::Cache')->CleanUp(
                Type => $Cache,
            );
        }
        }
);

1;
