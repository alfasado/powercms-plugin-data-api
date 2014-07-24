package DataAPIPowerCMS::DataAPI;

use strict;
use warnings;

use MT::DataAPI::Endpoint::Common;
use MT::DataAPI::Resource;

use CustomFields::Util qw( get_meta );
use lib qw( addons/PowerCMS.pack/lib );
use PowerCMS::Util qw( is_user_can );

sub _data_api_endpoint_get_customobject {
    my ( $app, $endpoint ) = @_;
    my ( $blog, $customobject ) = context_objects( @_ ) or return;
    my $class = $customobject->class;
    run_permission_filter( $app, 'data_api_list_permission_filter', $class ) or return;
    my $user = $app->user;
    if ( $user ) {
        if (! __permission( $user, $blog, $class ) ) {
            $user = undef;
        }
    }
    if ( (! $user ) && ( $customobject->status != 2 ) ) {
        return;
    }
    return $customobject;
}

sub _data_api_endpoint_get_banner {
    my ( $app, $endpoint ) = @_;
    my ( $blog, $banner ) = context_objects( @_ ) or return;
    my $class = 'campaign';
    run_permission_filter( $app, 'data_api_list_permission_filter', $class ) or return;
    my $user = $app->user;
    if ( $user ) {
        if (! __permission( $user, $blog, $class ) ) {
            $user = undef;
        }
    }
    if ( (! $user ) && ( $banner->status != 2 ) ) {
        return;
    }
    return $banner;
}

sub _data_api_endpoint_customobjects {
    my ( $app, $endpoint ) = @_;
    my ( $blog ) = context_objects( @_ ) or return;
    my $class = $app->param( 'class' ) || 'customobject';
    run_permission_filter( $app, 'data_api_list_permission_filter', $class ) or return;
    my $args;
    my $sort_order = 'descend';
    my $sort_by = 'id';
    my $user = $app->user;
    if ( $user ) {
        if (! __permission( $user, $blog, $class ) ) {
            $user = undef;
        }
    }
    my @sort_col = qw( authored_on modified_on period_on id keywords name );
    if ( my $sortBy = $app->param( 'sortBy' ) ) {
        if ( grep( /^$sortBy$/, @sort_col ) ) {
            $sort_by = $sortBy;
        }
    }
    if ( my $sortOrder = $app->param( 'sortOrder' ) ) {
        if ( $sortOrder eq 'ascend' ) {
            $sort_order = $sortOrder;
        }
    }
    $args->{ sort_by } = $sort_by;
    $args->{ direction } = $sort_order;
    my $limit = 10;
    if ( $app->param( 'limit' ) ) {
        $limit = $app->param( 'limit' ) + 0;
    }
    my $offset = 0;
    if ( $app->param( 'offset' ) ) {
        $offset = $app->param( 'offset' ) + 0;
    }
    $args->{ limit } = $limit;
    $args->{ offset } = $offset;
    my $terms = { blog_id => $blog->id };
    if (! $user ) {
        $terms->{ status } = 2;
    } else {
        if ( my $status = $app->param( 'status' ) ) {
            my $status_int = MT->model( $class )->status_int( $status );
            return $status_int;
            $terms->{ status } = $status_int;
        }
    }
    $terms->{ class } = $class;
    if ( my $search = $app->param( 'search' ) ) {
        $search = MT::Util::trim( $search );
        my $searchFields = $app->param( 'searchFields' ) || 'name,body,keywords';
        my @fields = split( /,/, $searchFields );
        for my $field( @fields ) {
            $field = MT::Util::trim( $field );
            $terms->{ $field } = { like => '%' . $search . '%' };
        }
    }
    if ( my $folder = $app->param( 'folder' ) ) {
        if ( my @folders = __folder_path_to_obj( $blog, $folder ) ) {
             $terms->{ category_id } = $folders[ 0 ]->id;
        }
    }
    my $group = $app->param( 'group' );
    my $group_id = $app->param( 'group_id' );
    if ( $group || $group_id ) {
        require CustomObject::CustomObjectGroup;
        require CustomObject::CustomObjectOrder;
        if (! $group_id ) {
            my $cg = CustomObject::CustomObjectGroup->load( { name => $group, blog_id => $blog->id } )
                or return _none_match();
            $group_id = $cg->id;
        }
        $args->{ 'join' } = [ 'CustomObject::CustomObjectOrder', 'customobject_id',
                   { group_id => $group_id, },
                   { 'sort' => 'order',
                     direction => 'ascend',
                   } ];
    }
    my $count = MT->model( $class )->count( $terms );
    my @custom_objects = MT->model( $class )->load( $terms, $args );
    return {
        totalResults => $count + 0,
        items => \@custom_objects,
    };
    return [];
}

sub _data_api_endpoint_banners {
    my ( $app, $endpoint ) = @_;
    my ( $blog ) = context_objects( @_ ) or return;
    my $class = 'campaign';
    run_permission_filter( $app, 'data_api_list_permission_filter', $class ) or return;
    my $args;
    my $sort_order = 'descend';
    my $sort_by = 'id';
    my $user = $app->user;
    if ( $user ) {
        if (! __permission( $user, $blog, $class ) ) {
            $user = undef;
        }
    }
    my @sort_col = qw( created_on modified_on publishing_on period_on id title );
    if ( my $sortBy = $app->param( 'sortBy' ) ) {
        if ( grep( /^$sortBy$/, @sort_col ) ) {
            $sort_by = $sortBy;
        }
    }
    if ( my $sortOrder = $app->param( 'sortOrder' ) ) {
        if ( $sortOrder eq 'ascend' ) {
            $sort_order = $sortOrder;
        }
    }
    $args->{ sort_by } = $sort_by;
    $args->{ direction } = $sort_order;
    my $limit = 10;
    if ( $app->param( 'limit' ) ) {
        $limit = $app->param( 'limit' ) + 0;
    }
    my $offset = 0;
    if ( $app->param( 'offset' ) ) {
        $offset = $app->param( 'offset' ) + 0;
    }
    $args->{ limit } = $limit;
    $args->{ offset } = $offset;
    my $terms = { blog_id => $blog->id };
    if (! $user ) {
        $terms->{ status } = 2;
    } else {
        if ( my $status = $app->param( 'status' ) ) {
            my $status_int = __campaign_status_int( $status );
            return $status_int;
            $terms->{ status } = $status_int;
        }
    }
    if ( my $search = $app->param( 'search' ) ) {
        $search = MT::Util::trim( $search );
        my $searchFields = $app->param( 'searchFields' ) || 'title,text,memo';
        my @fields = split( /,/, $searchFields );
        for my $field( @fields ) {
            $field = MT::Util::trim( $field );
            $terms->{ $field } = { like => '%' . $search . '%' };
        }
    }
    my $active = $app->param( 'active' );
    if ( $active ) {
        my $ts = current_ts( $blog );
        $terms->{ publishing_on } = { '<' => $ts };
        $terms->{ period_on }     = { '>' => $ts };
        $terms->{ status } = 2;
    }
    my $group = $app->param( 'group' );
    my $group_id = $app->param( 'group_id' );
    if ( $group || $group_id ) {
        require Campaign::CampaignGroup;
        require Campaign::CampaignOrder;
        if (! $group_id ) {
            my $cg = Campaign::CampaignGroup->load( { name => $group, blog_id => $blog->id } )
                or return _none_match();
            $group_id = $cg->id;
        }
        $args->{ 'join' } = [ 'Campaign::CampaignOrder', 'campaign_id',
                   { group_id => $group_id, },
                   { 'sort' => 'order',
                     direction => 'ascend',
                   } ];
    }
    my $count = MT->model( $class )->count( $terms );
    my @banners = MT->model( $class )->load( $terms, $args );
    return {
        totalResults => $count + 0,
        items => \@banners,
    };
}

sub _none_match {
    return {
        totalResults => 0,
        items => [],
    };
}

sub permalink {
    my ( $obj, $hash, $field, $stash ) = @_;
    return $obj->permalink;
}

sub folder {
    my ( $obj, $hash, $field, $stash ) = @_;
    my $folder_path = $obj->folder_path;
    my $path2folder;
    if ( $folder_path ) {
        my @pathes;
        for my $f ( @$folder_path ) {
            push ( @pathes, $f->basename );
        }
        $path2folder = join( '/', @pathes );
        $path2folder = '/' . $path2folder . '/';
    } else {
        $path2folder = '/';
    }
    return $path2folder;
}

sub customFields {
    my ( $obj, $hash, $field, $stash ) = @_;
    require CustomFields::DataAPI;
    my $meta = get_meta( $obj );
    [   map {
            +{  basename => $_->basename,
                value    => $meta->{ $_->basename },
            };
        } @{ CustomFields::DataAPI::custom_fields( $obj ) }
    ];
}

sub tags {
    my ( $obj, $hash, $field, $stash ) = @_;
    return [ $obj->tags ];
}

sub image_width {
    my ( $obj, $hash, $field, $stash ) = @_;
    my $asset = $obj->image or return 0;
    if ( $asset->class eq 'image' ) {
        return $asset->image_width;
    }
    return 0;
}

sub image_height {
    my ( $obj, $hash, $field, $stash ) = @_;
    my $asset = $obj->image or return 0;
    if ( $asset->class eq 'image' ) {
        return $asset->image_height;
    }
    return 0;
}

sub status_text {
    my ( $obj, $hash, $field, $stash ) = @_;
    return $obj->status_text;
}

sub __folder_path_to_obj {
    my ( $blog, $path ) = @_;
    my $class = MT->model( 'folder' );
    my @cat_path = $path =~ m@(\[[^]]+?\]|[^]/]+)@g;
    @cat_path = map { $_ =~ s/^\[(.*)\]$/$1/; $_ } @cat_path;
    my $last_cat_id = 0;
    my $cat;
    my $top  = shift @cat_path;
    my @cats = $class->load(
        {   basename  => $top,
            parent => 0,
            blog_id => $blog->id,
        }
    );
    if ( @cats ) {
        for my $label ( @cat_path ) {
            my @parents = map { $_->id } @cats;
            @cats = $class->load(
                {   basename  => $label,
                    parent => \@parents,
                    blog_id => $blog->id,
                },
            ) or last;
        }
    }
    if ( !@cats && $path ) {
        @cats = (
            $class->load(
                {   basename => $path,
                    blog_id => $blog->id,
                },
            )
        );
    }
    @cats;
}

sub __campaign_status_int {
    my $status = shift;
    $status = uc( $status );
    return 1 if $status eq 'DRAFT' || $status eq 'HOLD';
    return 2 if $status eq 'PUBLISHED' || $status eq 'PUBLISHING' || $status eq 'RELEASE';
    return 3 if $status eq 'RESERVED' || $status eq 'FUTURE';
    return 4 if $status eq 'FINISED' || $status eq 'CLOSED' || $status eq 'ENDED';
    return 0;
}

sub __permission {
    my ( $user, $blog, $class ) = @_;
    return 1 if $user->is_superuser;
    if ( is_user_can( $blog, $user, 'administer_blog' ) ) {
        return 1;
    }
    if ( is_user_can( $blog, $user, 'administer_website' ) ) {
        return 1;
    }
    if ( is_user_can( $blog, $user, 'manage_' . $class ) ) {
        return 1;
    }
    return 0;
}

1;