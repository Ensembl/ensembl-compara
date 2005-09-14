package EnsEMBL::Web::Object::News;

use strict;
use warnings;
no warnings "uninitialized";
use CGI qw(escape);

use EnsEMBL::Web::Object;
use EnsEMBL::Web::Factory::News;

our @ISA = qw(EnsEMBL::Web::Object);


#------------------- ACCESSOR FUNCTIONS -----------------------------

sub items { return $_[0]->Obj->{'items'}; }
sub releases   { return $_[0]->Obj->{'releases'};   }
sub all_cats   { return $_[0]->Obj->{'all_cats'};   }
sub all_spp   { return $_[0]->Obj->{'all_spp'};   }
sub valid_spp   { return $_[0]->Obj->{'valid_spp'};   }
sub current_spp   { return $_[0]->Obj->{'current_spp'};   }
sub valid_rels   { return $_[0]->Obj->{'valid_rels'};   }


sub save_to_db {
    my $self = shift;
    my $itemref = $self->Obj->{'items'}[0];
    my %item = %{$itemref};
    my $result;

    if ($item{'news_item_id'}) { # saving updates to an existing item
        $result = $self->EnsEMBL::Web::Factory::News::news_adaptor->update_news_item($itemref);
    }
    else { # inserting a new item into database
        $result = $self->EnsEMBL::Web::Factory::News::news_adaptor->add_news_item($itemref);
    }
    return $result;
}


1;
