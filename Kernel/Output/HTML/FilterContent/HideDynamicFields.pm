# --
# Copyright (C) 2017 - 2022 Perl-Services.de, https://www.perl-services.de/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::FilterContent::HideDynamicFields;

use strict;
use warnings;

our @ObjectDependencies = qw(
    Kernel::Config
    Kernel::System::Queue
    Kernel::System::JSON
    Kernel::System::Web::Request
    Kernel::Output::HTML::Layout
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{UserID}      = $Param{UserID};

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject  = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $JSONObject   = $Kernel::OM->Get('Kernel::System::JSON');
    my $QueueObject  = $Kernel::OM->Get('Kernel::System::Queue');
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # get template name
    #my $Templatename = $Param{TemplateFile} || '';
    my $Action = $ParamObject->GetParam( Param => 'Action' );

    return 1 if !$Action;
    return 1 if !$Param{Templates}->{$Action};

    my $TicketID = $ParamObject->GetParam( Param => 'TicketID' );
    my %Ticket;

    if ( $TicketID ) {
        %Ticket = $TicketObject->TicketGet(
            TicketID => $TicketID,
            UserID   => $LayoutObject->{UserID},
        );
    }

    my $Config = $ConfigObject->Get('HideDynamicFields::Filter') || {};

    my %QueueList        = $QueueObject->QueueList( UserID => 1 );
    my %QueueListReverse = reverse %QueueList;

    my @Binds;
    my %Rules;
    my $HideJS = '';

    for my $Name ( sort keys %{ $Config } ) {
        my $BindJS = sprintf q~$('#%s').bind('change', function() {
            DoHideDynamicFields();
        });~, $Name;

        my $TicketKey = $Name;

        for my $Value ( keys %{ $Config->{$Name} || {} } ) {
            my $OrigValue = $Value;

            if ( $Name eq 'Dest' ) {
                $Value = sprintf "%s||%s", $QueueListReverse{$Value}, $Value;
                $TicketKey = 'Queue';
            }

            my @Fields = split /\s*,\s*/, $Config->{$Name}->{$OrigValue};
            $Rules{$Name}->{$Value} = \@Fields;

            if ( $Ticket{$TicketKey} eq $OrigValue ) {
                $HideJS .= sprintf "HideDynamicField('%s'); ", $_ for @Fields;
            }
        }

        push @Binds, $BindJS;
    }

    my $JSON = $JSONObject->Encode( Data => \%Rules );

    my $ConfigValueTexts = $ConfigObject->Get('HideDynamicFields::ValueTexts');
    my $ValueText        = $JSONObject->Encode( Data => $ConfigValueTexts );

    my $JS = qq~
        <script type="text/javascript">//<![CDATA[
        var HideDynamicFieldRules = $JSON;
        var ValueText             = $ValueText;

        function ShowDynamicFields() {
            \$('.Row').show();
        }

        function DoHideDynamicFields() {
            ShowDynamicFields();
            \$.each( HideDynamicFieldRules, function( Field, Config ) {
                var Type = ValueText[Field];

                if ( Type === "" || Type === undefined ) {
                    Type = 'id';
                }

                Type = Type.toLowerCase();

                var PossibleValues = {
                    id:  \$('#' + Field).val(),
                    text: \$('#' + Field + ' option:selected').text(),
                    bool: (\$('#' + Field).is(':checked') ? 1 : 0),
                };

                var Current = PossibleValues[Type];

                if ( Current === "" ) {
		    return;
		}

                var ToHide  = Config[Current];
                if ( ToHide === undefined ) {
		    return;
		}

                \$.each( ToHide, function( Index, Name ) {
                    HideDynamicField( Name );
                });
            });
        }

        function HideDynamicField( FieldName ) {
            \$('.Row_DynamicField_' + FieldName ).val('');
            \$('.Row_DynamicField_' + FieldName ).hide();
        }

        function InitHideDynamicField () {
            @Binds
        }

        Core.App.Ready( function() {
            InitHideDynamicField();
        });

        $HideJS
        //]]></script>
    ~;

    my $Subaction = $ParamObject->GetParam( Param => 'Subaction' );
    if ( $Action =~ m{(?:Agent|Customer)TicketProcess}xms && $Subaction eq 'DisplayActivityDialogAJAX' ) {
        ${ $Param{Data} } =~ s{.*\K$}{
            <script type="text/javascript">InitHideDynamicField(); DoHideDynamicFields()</script>
        };
    }
    ${ $Param{Data} } =~ s{</body}{$JS</body};

    return 1;
}

1;
