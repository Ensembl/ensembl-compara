package EnsEMBL::Web::HelpView::Category;

=head1 NAME

EnsEMBL::Web::HelpView::Category - object representing a Ensembl help category

=head1 SYNOPSIS

my $category = EnsEMBL::Web::HelpView::Category->new(
                    -CATEGORY_ID => 1,
                    -NAME        => "Other",
                    -PRIORITY    => 7,
);
print "Category name: " . $category->name . "\n";

=head1 DESCRIPTION

Simple object representing an Ensembl help category. Uses AUTOLOAD for
accessors.

=head1 LICENCE

This code is distributed under an Apache style licence:
Please see http://www.ensembl.org/code_licence.html for details

=head1 AUTHOR

Patrick Meidl <pm2@sanger.ac.uk>

=head1 CONTACT

Post questions to the EnsEMBL development list ensembl-dev@ebi.ac.uk

=cut

use strict;
use warnings;
no warnings 'uninitialized';

use Bio::EnsEMBL::Utils::Argument qw(rearrange);

# allowed methods (for AUTOLOAD)
our %methods = map { $_ => 1 } qw(category_id name priority);
    
=head2 new

  Arg [-CATEGORY_ID]    : Int - category ID
  Arg [-NAME]           : String $name - category name
  Arg [-PRIORITY]       : Int - priority (used for ordering categories)
  
  Example     : my $category = EnsEMBL::Web::HelpView::Category->new(
                    -CATEGORY_ID => 1,
                    -NAME        => "Other",
                    -PRIORITY    => 7,
                );
                print "Category name: " . $category->name . "\n";
  Description : object constructor
  Return type : EnsEMBL::Web::HelpView::Category
  Exceptions  : none
  Caller      : general

=cut

sub new {
    my $caller = shift;
    my $class = ref($caller) || $caller;

    my ($category_id, $name, $priority) = rearrange(['CATEGORY_ID', 'NAME', 'PRIORITY'], @_);

    my $self = {
           'category_id'    => $category_id,
           'name'           => $name,
           'priority'       => $priority,
    };
    bless($self, $class);
    return $self;
}

=head2 AUTOLOAD

  Arg[1]      : (optional) String/Object - attribute to set
  Example     : # setting a attribute
                $self->attr($val);
                # getting the attribute
                $self->attr;
                # undefining an attribute
                $self->attr(undef);
  Description : lazy function generator for getters/setters
  Return type : String/Object
  Exceptions  : none
  Caller      : general

=cut

sub AUTOLOAD {
    my $self = shift;
    my $attr = our $AUTOLOAD;
    $attr =~ s/.*:://;
    return unless $attr =~ /[^A-Z]/;
    die ("Invalid attribute method: $attr") unless $methods{$attr};
    no strict 'refs';
    *{$AUTOLOAD} = sub {
        $_[0]->{$attr} = $_[1] if (@_ > 1);
        return $_[0]->{$attr};
    };
    $self->{$attr} = shift if (@_);
    return $self->{$attr};
}

1;

