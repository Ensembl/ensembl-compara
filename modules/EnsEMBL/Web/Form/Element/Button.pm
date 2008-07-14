package EnsEMBL::Web::Form::Element::Button;

use EnsEMBL::Web::Form::Element;
use CGI qw(escapeHTML);
our @ISA = qw( EnsEMBL::Web::Form::Element );

sub new { 
    my $class = shift; 
    my %params = @_;
    my $self = $class->SUPER::new( @_ );
    return $self;
 }

sub render { 
    return sprintf( '<input type="button" name="%s" id="%s" value="%s" class="red-button" />', 
		    CGI::escapeHTML($_[0]->name) || 'submit', 
        CGI::escapeHTML($_[0]->id) || 'button_'.CGI::escapeHTML($_[0]->name),
		    CGI::escapeHTML($_[0]->value), 
		    );
}  
1;
