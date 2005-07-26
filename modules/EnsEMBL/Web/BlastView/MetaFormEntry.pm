#----------------------------------------------------------------------
#
# TODO docs
#
#----------------------------------------------------------------------

package EnsEMBL::Web::BlastView::MetaFormEntry;

use strict;
use warnings;
no warnings "uninitialized";

use Carp;
use Data::Dumper;

use EnsEMBL::Web::BlastView::Meta;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::BlastView::Meta);

# Define a generic form entry (e.g. individual checkbox)
sub _object_template{ 
  return 
    (
     -parent        => '', # ID of parent object (i.e. form name)
     
     -available      => [1], # Availability. Array exp's ANDed
     -error          => [], # Error detection code_ref/regexp/value
     -cgi_processing => [], # 'cgi value' processing code references 
     -type           => '', # Type of form element

     -name_suffix   => '', # suffix for CGI name
     -cgi_name      => '', # CGI name itself, defaults to parent+name_suffix
     -cgi_processing=> '', # Calls CGI processing code refs
     -value         => '', # CGI value

     -where         => '', # API where clause
     -api_filter    => '', # API filter clause
     -select        => '', # API select clause
     -api_attribute => '', # API attribute clause

     -sequence_format=> '', # API sequence_format clause 
     -sequence_value=> '',  # API sequence_format value (defaults to -value)

     -label         => '', # MainPanel display label
     -label_summary => '', # SummaryPanel display label
     -default       => '', # Default value
     -src           => '', # Location for image buttons
     -validate      => '', # regexp or method to be called on validate
     -on_set        => '', # method to be called to parse value
     -options       => '', # Option list for select form. Can be method
     
#     -available     => 1,  # Form entry availability flag

     -cgi_size      => '', # Textbox/select size
     -cgi_maxlength => '', # Textbox max length
     -cgi_cols      => '', # Textarea cols
     -cgi_rows      => '', # Textarea rows
     -cgi_multiple  => '', # Select list MULTIPLE
     -cgi_onchange  => '', # java script handler onchange 
     -cgi_onclick   => '', # java script handler onclick
     -cgi_onselect  => '', # java script handler onselect
     -cgi_onfocus   => '', # java script handler onfocus
     -html_div      => '', # HTML <DIV> form for use with dynamic/JS

     -hyperlinks    => [], # Hyperlink object assocuated with this form entry

     -name          => '', # Deprecated
     -species       => ['__ALL__'], # Deprecated 
     -focus         => ['__ALL__'], # Deprecated
     -outtype       => ['__ALL__'], # Deprecated
     -multispecies  => 1,  # Deprecated
    );
}

#----------------------------------------------------------------------

=head2 get_cgi_name

  Arg [1]   : NONE
  Function  : Method override for generation of cgi param names
              Returns 
  Returntype: string: name of cgi param for this form element
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub get_cgi_name {
   my $self = shift;
   return $self->SUPER::get_cgi_name ? 
          $self->SUPER::get_cgi_name :
	  $self->get_parent.$self->get_name_suffix;
}

#----------------------------------------------------------------------



1;
