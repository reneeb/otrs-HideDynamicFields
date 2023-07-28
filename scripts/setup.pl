#!/usr/bin/perl

use v5.24;

use strict;
use warnings;

use lib qw(/opt/otrs /opt/otrs/Kernel/cpan-lib /opt/znuny /opt/znuny/Kernel/cpan-lib);

use Kernel::System::ObjectManager;

local $Kernel::OM = Kernel::System::ObjectManager->new;

setup_dynamic_fields();
hide_show_fields();

sub hide_show_fields {
    my $Config = do { local $/; <DATA> };

    my $Home = $Kernel::OM->Get('Kernel::Config')->Get('Home');
    open my $Fh, '>', $Home . '/Kernel/Config/Files/ZZZHideDynamicFields.pm' or warn $!;
    print $Fh $Config;
    close $Fh or warn $!;
}

sub setup_dynamic_fields {
    my $ValidObject        = $Kernel::OM->Get('Kernel::System::Valid');
    my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $CommandObject      = $Kernel::OM->Get('Kernel::System::Console::Command::Admin::DynamicField::ScreenConfig');
    my $ZnunyHelperObject  = $Kernel::OM->Get('Kernel::System::ZnunyHelper');

    my $ValidID = $ValidObject->ValidLookup(
        Valid => 'valid',
    );

    my @DynamicFields = _get_definitions();

    my $DynamicFieldList = $DynamicFieldObject->DynamicFieldListGet(
        Valid => 0,
    );

    # get the list of order numbers (is already sorted).
    my @DynamicfieldOrderList;
    for my $Dynamicfield ( @{$DynamicFieldList} ) {
        push @DynamicfieldOrderList, $Dynamicfield->{FieldOrder};
    }

    # get the last element from the order list and add 1
    my $NextOrderNumber = 1;
    if (@DynamicfieldOrderList) {
        $NextOrderNumber = $DynamicfieldOrderList[-1] + 1;
    }

    # create a dynamic fields lookup table
    my %DynamicFieldLookup;
    for my $DynamicField ( @{$DynamicFieldList} ) {
        next if ref $DynamicField ne 'HASH';
        $DynamicFieldLookup{ $DynamicField->{Name} } = $DynamicField;
    }

    my %ScreenConfigurations;

    # create or update dynamic fields
    DYNAMICFIELD:
    for my $DynamicField (@DynamicFields) {

        my $CreateDynamicField;

        # check if the dynamic field already exists
        if ( ref $DynamicFieldLookup{ $DynamicField->{Name} } ne 'HASH' ) {
            $CreateDynamicField = 1;
        }

        # check if new field has to be created
        if ($CreateDynamicField) {
            $ScreenConfigurations{$_}->{$DynamicField->{Name}} = 1 for @{ $DynamicField->{Screens} || [] };

            # create a new field
            my $FieldID = $DynamicFieldObject->DynamicFieldAdd(
                Name       => $DynamicField->{Name},
                Label      => $DynamicField->{Label},
                FieldOrder => $NextOrderNumber,
                FieldType  => $DynamicField->{FieldType},
                ObjectType => $DynamicField->{ObjectType},
                Config     => $DynamicField->{Config},
                ValidID    => $ValidID,
                UserID     => 1,
            );
            next DYNAMICFIELD if !$FieldID;

            # increase the order number
            $NextOrderNumber++;
        }

    }

    $ZnunyHelperObject->_DynamicFieldsScreenEnable(%ScreenConfigurations) if %ScreenConfigurations;

    return 1;
}

sub _get_definitions {

    # define all dynamic fields
    my @dynamic_fields = (
        {
            # just for public access
            Name       => 'UUID',
            Label      => 'Token for public access',
            FieldType  => 'Text',
            ObjectType => 'Ticket',
            Config     => {
                DefaultValue => '',
                Link         => '',
            },
            Screens => [qw/
                AgentTicketPhone
                AgentTicketCompose
            /],
        },
        {
            Name       => 'YesNo',
            Label      => 'Yes or No',
            FieldType  => 'Dropdown',
            ObjectType => 'Ticket',
            Config     => {
                DefaultValue   => '1',
                Link           => '',
                PossibleValues => {
                    1 => 'Ja',
                    2 => 'Nein',
                },
            },
            Screens => [qw/
                AgentTicketPhone
                AgentTicketCompose
            /],
        },
        {
            Name       => 'SampleDate',
            Label      => 'Date (Sample)',
            FieldType  => 'Date',
            ObjectType => 'Ticket',
            Config     => {
                DefaultValue => '',
                Link         => '',
            },
            Screens => [qw/
                AgentTicketPhone
                AgentTicketCompose
            /],
        },
    );

    return @dynamic_fields;
}


__DATA__
# OTRS config file (automatically generated)
# VERSION:2.0
package Kernel::Config::Files::ZZZHideDynamicFields;

use strict;
use warnings;
no warnings 'redefine'; ## no critic
use utf8;

sub Load {
    my ($File, $Self) = @_;

    $Self->{'HideDynamicFields::Filter'} = {
        Dest => {
            Misc => 'SampleDate,YesNo',
            Junk => 'UUID',
        },  
        QueueID => {
            Misc => 'UUID, YesNo',
            Postmaster => 'SamleDate , UUID, YesNo',
        },
    };      
}

1;

