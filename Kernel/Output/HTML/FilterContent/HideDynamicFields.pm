# --
# Copyright (C) 2017 Perl-Services.de, http://www.perl-services.de/
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

    # get template name
    #my $Templatename = $Param{TemplateFile} || '';
    my $Action = $ParamObject->GetParam( Param => 'Action' );

    return 1 if !$Action;
    return 1 if !$Param{Templates}->{$Action};

    my $Config = $ConfigObject->Get('HideDynamicFields::Filter') || {};

    my %QueueList        = $QueueObject->QueueList( UserID => 1 );
    my %QueueListReverse = reverse %QueueList;

    my @Binds;
    my %Rules;

    for my $Name ( sort keys %{ $Config } ) {
        my $BindJS = sprintf q~$('#%s').bind('change', function() {
            DoHideDynamicFields();
        });~, $Name;


        for my $Value ( keys %{ $Config->{$Name} || {} } ) {
            my $OrigValue = $Value;

            if ( $Name eq 'Dest' ) {
                $Value = sprintf "%s||%s", $QueueListReverse{$Value}, $Value;
            }

            $Rules{$Name}->{$Value} = [ split /\s*,\s*/, $Config->{$Name}->{$OrigValue} ];
        }

        push @Binds, $BindJS;
    }

    my $JSON = $JSONObject->Encode( Data => \%Rules );

    my $JS = qq~
        <script type="text/javascript">//<![CDATA[
        var HideDynamicFieldRules = $JSON;

        function ShowDynamicFields() {
            \$('.Row').show();
        }

        function DoHideDynamicFields() {
            ShowDynamicFields();
            \$.each( HideDynamicFieldRules, function( Field, Config ) {
                var Current = \$('#' + Field).val();
                var ToHide  = Config[Current];
                \$.each( ToHide, function( Index, Name ) {
                    HideDynamicField( Name );
                });
            });
        }

        function HideDynamicField( FieldName ) {
            \$('.Row_DynamicField_' + FieldName ).val('');
            \$('.Row_DynamicField_' + FieldName ).hide();
        }

        Core.App.Ready( function() {
            @Binds
        });
        //]]></script>
    ~;

    ${ $Param{Data} } =~ s{</body}{$JS</body};

    return 1;
}

1;
