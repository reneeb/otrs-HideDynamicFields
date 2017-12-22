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

use Kernel::System::Queue;
use Kernel::System::JSON;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get needed objects
    for my $Object (
        qw(MainObject ConfigObject LogObject LayoutObject ParamObject DBObject EncodeObject)
        )
    {
        $Self->{$Object} = $Param{$Object} || die "Got no $Object!";
    }

    $Self->{UserID}      = $Param{UserID};
    $Self->{QueueObject} = Kernel::System::Queue->new( %{$Self} );
    $Self->{JSONObject}  = Kernel::System::JSON->new( %{$Self} );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # get template name
    #my $Templatename = $Param{TemplateFile} || '';
    my $Action = $Self->{ParamObject}->GetParam( Param => 'Action' );

    return 1 if !$Action;
    return 1 if !$Param{Templates}->{$Action};

    my $Config = $Self->{ConfigObject}->Get('HideDynamicFields::Filter') || {};

    my %QueueList        = $Self->{QueueObject}->QueueList( UserID => 1 );
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

    my $JSON = $Self->{JSONObject}->Encode( Data => \%Rules );

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
