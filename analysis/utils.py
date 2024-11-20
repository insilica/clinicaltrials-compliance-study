import numpy as np
import pandas as pd
import os
import glob


def process_months_to_report(df_):
    df_['common.primary_completion_date_imputed'] = pd.to_datetime(
        df_['common.primary_completion_date_imputed'], errors='coerce')
    
    df_['common.results_received_date'] = pd.to_datetime(
        df_['common.results_received_date'], errors='coerce')
    
    # df['common.results_received_date'] = \
    #     df['common.results_received_date'].dt.tz_localize('UTC')  # Localize tz-naive to UTC
    df_['common.primary_completion_date_imputed'] = df_[
        'common.primary_completion_date_imputed'].dt.tz_localize('UTC')  # Localize tz-naive to UTC

    df_['rf_months_to_report'] = (df_['common.results_received_date'] - 
     df_['common.primary_completion_date_imputed']).dt.days/30.44

    df_['rf_months_to_report_plot'] = df_['rf_months_to_report'].fillna(65)
    df_.loc[df_['rf_months_to_report_plot'] < 0, 'rf_months_to_report_plot'] = 0 

    df_['report_within_12'] = df_['rf_months_to_report'] <= 12 + 1/30.5
    df_['report_within_36'] = df_['rf_months_to_report'] <= 36 + 1/30.5
    try:
        df_['rr.primary_purpose'].replace({'Diagnostic':'Other'})
    except: 
        pass
    return df_


def get_d_rates(df, within):
    groups = ['funding','phase', 'intervention','purpose', 'status'] 
    groups_col = [ 
        'rr.funding', 
        'common.phase.norm', 
        'rr.intervention_type', 
        'rr.primary_purpose',
        'rr.overall_status'
    ]

    d_group_col = dict(zip(groups, groups_col))
    d_rates, d_props, d_n, d_N = {}, {}, {}, {}
    for group in groups:
        col_group = d_group_col[group]
        # rates: reporting rate n/N, props: proportion of composition, n: reporting within X months, N: total
        d_rates[group] = df.groupby(col_group)['rf_months_to_report'].apply(
            lambda x: (x <= within + 1/30.5).sum()/len(x)).to_dict()
        d_props[group] = df[col_group].value_counts(normalize=True).to_dict()
        d_N[group] = df.groupby(col_group).size().to_dict()
        d_n[group] = df.groupby(col_group)['rf_months_to_report'].apply(
            lambda x: (x <= within + 1/30.5).sum()).to_dict()

    return d_rates, d_props, d_n, d_N



def flatten_d(d, rate_col = 'rate'):
    df_ = pd.DataFrame(columns={'group':[], 'subgroup':[], rate_col:[]})
    groups = d.keys()
    for group in groups:
        d_group = d[group]
        subgroups = d_group.keys()
        rates = d_group.values()
        row = pd.DataFrame({'group':group, 'subgroup':subgroups, rate_col:rates})
        df_ = pd.concat([df_, row])
    return df_

    
def get_prepost_dataframes(
    d_rates_pre, d_rates_post, d_rates_overall,
    d_props_pre, d_props_post, d_props_overall,
    d_n_pre, d_n_post, d_n_overall,
    d_N_pre, d_N_post, d_N_overall,
    ):
    
    df_pre = flatten_d(d_rates_pre, rate_col='rate_pre').merge(
        flatten_d(d_props_pre, rate_col='prop_pre')).merge(
        flatten_d(d_n_pre, rate_col='n_pre')).merge(
        flatten_d(d_N_pre, rate_col='N_pre'))
    
    df_post = flatten_d(d_rates_post, rate_col='rate_post').merge(
        flatten_d(d_props_post, rate_col='prop_post')).merge(
        flatten_d(d_n_post, rate_col='n_post')).merge(
        flatten_d(d_N_post, rate_col='N_post'))
    
    df_overall = flatten_d(d_rates_overall, rate_col='rate_overall').merge(
        flatten_d(d_props_overall, rate_col='prop_overall')).merge(
        flatten_d(d_n_overall, rate_col='n_overall')).merge(
        flatten_d(d_N_overall, rate_col='N_overall'))

    
    df_prepost = df_pre.merge(df_post, on=['group', 'subgroup'], how='left'
                ).merge(df_overall, on=['group', 'subgroup'], how='left')
    
    df_prepost['diff_rate'] = df_prepost['rate_post'] - df_prepost['rate_pre']
    return df_prepost


def get_dataframes(path_pre_processed, path_post_processed):
    # path_pre = "../brick/pre-post-2017_processed/1_20200101_hlact_studies.parquet")
    # path_post = "../brick/pre-post-2017_processed/2_20240101_hlact_studies.parquet")
    df_pre = pd.read_parquet(path_pre_processed)
    df_post = pd.read_parquet(path_post_processed)
    
    df_pre = process_months_to_report(df_pre)
    df_post = process_months_to_report(df_post)
    df_overall = pd.concat([df_pre, df_post])
    #  Reduce duplicates, takes latest version number
    df_overall = df_overall[ 
        df_overall.groupby('schema1.nct_id_1')['schema1.version_number'
        ].rank(method='max') == 1 
    ]

    # Gets pre and post aggregate rates within 12 and 36 months
    groups = ['funding','phase', 'intervention','purpose'] 
    groups_col = [ 'rr.funding', 'common.phase.norm', 'rr.intervention_type', 'rr.primary_purpose']
    
    d_rates_pre_12, d_props_pre_12, d_n_pre_12, d_N_pre_12 = get_d_rates(df_pre, within=12)
    d_rates_post_12, d_props_post_12, d_n_post_12, d_N_post_12 = get_d_rates(df_post, within=12)
    d_rates_overall_12, d_props_overall_12, d_n_overall_12, d_N_overall_12 = get_d_rates(df_overall, within=12)
    
    d_rates_pre_36, d_props_pre_36, d_n_pre_36, d_N_pre_36 = get_d_rates(df_pre, within=36)
    d_rates_post_36, d_props_post_36, d_n_post_36, d_N_post_36 = get_d_rates(df_post, within=36)
    d_rates_overall_36, d_props_overall_36, d_n_overall_36, d_N_overall_36 = get_d_rates(df_overall, within=36)
    
    
    df_prepost_12 = get_prepost_dataframes(d_rates_pre_12, d_rates_post_12, d_rates_overall_12, 
                                           d_props_pre_12, d_props_post_12, d_props_overall_12,
                                           d_n_pre_12, d_n_post_12, d_n_overall_12,
                                           d_N_pre_12, d_N_post_12, d_N_overall_12
                                          )
    df_prepost_36 = get_prepost_dataframes(d_rates_pre_36, d_rates_post_36, d_rates_overall_36,
                                           d_props_pre_36, d_props_post_36, d_props_overall_36,
                                           d_n_pre_36, d_n_post_36, d_n_overall_36,
                                           d_N_pre_36, d_N_post_36, d_N_overall_36
                                          )

        
    return df_pre, df_post, df_overall, df_prepost_12, df_prepost_36


