import numpy as np
import pandas as pd
import bokeh.plotting
from bokeh.models import NumeralTickFormatter
bokeh.io.output_notebook()
import iqplot
import warnings
warnings.filterwarnings('ignore')
import utils
from scipy.stats import permutation_test
from tqdm import tqdm

from pathlib import Path

# TABLES OF RATES OF REPORTING OVERALL, SUBGROUPS
# TABLES OF COMPOSITION OF SUBGROUPS

def table_rates_overall(df_overall, df_pre, df_post):
    _ = []
    for df_, i in zip([df_overall, df_pre, df_post], ['overall', 'pre', 'post']):
        N = len(df_)
        n_within_12 = len(df_.loc[df_['report_within_12']])
        n_within_36 = len(df_.loc[df_['report_within_36']])
        p_within_12 = np.round(n_within_12 / N * 100, 1)
        p_within_36 = np.round(n_within_36 / N * 100, 1)
        print(i, 'N = ', N, 'trials')
        print('% report within 12 months:', p_within_12)
        print('% report within 36 months:', p_within_36, end='\n\n')

        # Add to table to output csv
        _.append(pd.DataFrame({'name':[f'N_trials_{i}'], 'value':[N]}))
        _.append(pd.DataFrame({'name':[f'n_within_12_{i}'], 'value':[n_within_12]}))
        _.append(pd.DataFrame({'name':[f'n_within_36_{i}'], 'value':[n_within_36]}))
        _.append(pd.DataFrame({'name':[f'p_within_12_{i}'], 'value':[p_within_12]}))
        _.append(pd.DataFrame({'name':[f'p_within_36_{i}'], 'value':[p_within_36]}))
        
    df_table = pd.concat(_)
    return df_table


def table_rates_subgroup(df_prepost_12, df_prepost_36):
    _ = []
    for df_, i in zip([df_prepost_12, df_prepost_36], ['12mo', '36mo']):
        df_mod = df_.copy()
        df_mod['rate_pre'] = np.round(df_mod['rate_pre']*100,1)
        df_mod['rate_post'] = np.round(df_mod['rate_post']*100,1)
        df_mod['diff_rate'] = np.round(df_mod['diff_rate']*100,1)
        
        df_mod = df_mod.rename(columns={
            'rate_pre': f'rate_window1_{i} (%)', 
            'rate_post': f'rate_window2_{i} (%)', 
            'diff_rate': f'diff_rate_{i} (%)', 
            })[['group', 'subgroup', f'rate_window1_{i} (%)', f'rate_window2_{i} (%)', f'diff_rate_{i} (%)']]
        _.append(df_mod)
    
    df_table_rates_subgroups = _[0].merge(_[1], how='left', on=['group', 'subgroup'])
    
    return df_table_rates_subgroups


def table_composition_subgroup(df_prepost_12):
    df_ = df_prepost_12[['group', 'subgroup', 'prop_pre', 'prop_post', 'prop_overall']]
    df_['diff_prop_prepost'] = df_['prop_post'] - df_['prop_pre']
    df_['diff_prop_prepost'] = np.round(df_['diff_prop_prepost']*100, 1)
    df_['prop_pre'] = np.round(df_['prop_pre']*100, 1)
    df_['prop_post'] = np.round(df_['prop_post']*100, 1)
    df_['prop_overall'] = np.round(df_['prop_overall']*100, 1)
    
    
    return df_



# LOLLIPOP PLOTTER
def _lollipop_plotter(df_prepost, within=36):
    
    # # Create [(group, subgroup)...] for bokeh y-axis
    # tuples = []
    # for group, col_group in zip(groups, groups_col):
    #     subgroup = df_pre[col_group].dropna().unique()
    #     for x in subgroup:
    #         tuples.append((group, x))
    # copied and pasted from above, rearranged

    tuples = [
         ('funding', 'Industry'),
         ('funding', 'NIH'),
         ('funding', 'Other'),
         ('phase', 'Phase 1/2 & 2'),
         ('phase', 'Phase 2/3 & 3'),
         ('phase', 'Phase 4'),
         # ('phase', 'Not applicable'),
         ('intervention', 'Biological'),
         ('intervention', 'Drug'),
         ('intervention', 'Device'),
         ('intervention', 'Other'),
         ('purpose', 'Treatment'),
         ('purpose', 'Prevention'),
         ('purpose', 'Other'),
         ('status', 'Completed'),
         ('status', 'Terminated')
    ]
    
    df_prepost['group_plot'] = df_prepost.apply(lambda x: (x.group, x.subgroup), axis=1)

    df_prepost['multi_line_xs'] = df_prepost.apply(lambda x: (x.rate_pre, x.rate_post), axis=1)
    df_prepost['multi_line_ys'] = df_prepost.apply(lambda x: (x.group_plot, x.group_plot), axis=1)

    color_pre = "#899DE6"
    color_post = "darkblue"
    size_dot = 9
    height, width = 450, 500
    p = bokeh.plotting.figure(
        output_backend='svg',
        y_range=bokeh.models.FactorRange(*tuples[::-1]), 
        height=height, width=width, title=f"Results reported within {within} months",
        x_axis_label=f'% reporting within {within} months', x_range=(0,1)
        #toolbar_location=None, tools=""
    )
    p.multi_line(xs='multi_line_xs', ys='multi_line_ys', 
                 source=df_prepost, color='#ababab', line_width=1.3, line_dash='dotted')
    p.circle(y='group_plot', x='rate_pre', source=df_prepost, color=color_pre, size=size_dot)
    p.circle(y='group_plot', x='rate_post', source=df_prepost, color=color_post, size=size_dot)
    
    p.x_range.start = 0
    p.y_range.range_padding = 0.1
    p.yaxis.major_label_orientation = 0
    p.ygrid.grid_line_color = None
    
    p.xaxis[0].formatter = NumeralTickFormatter(format="0%")
    p.xaxis.ticker = np.arange(-0.1,1.1, 0.1)
    
    return p


def plot_lollipop(df_prepost_12, df_prepost_36):      
    
    p_12 = _lollipop_plotter(df_prepost_12, within=12)
    p_36 = _lollipop_plotter(df_prepost_36, within=36)

    return p_12, p_36


# BOX PLOTS BY YEAR
def plot_boxplot_yearly():
    df_12 = pd.read_parquet("brick/yearly_obs36_processed/1_20120101_hlact_studies.parquet")
    df_13 = pd.read_parquet("brick/yearly_obs36_processed/2_20130101_hlact_studies.parquet")
    df_14 = pd.read_parquet("brick/yearly_obs36_processed/3_20140101_hlact_studies.parquet")
    df_15 = pd.read_parquet("brick/yearly_obs36_processed/4_20150101_hlact_studies.parquet")
    df_16 = pd.read_parquet("brick/yearly_obs36_processed/5_20160101_hlact_studies.parquet")
    df_17 = pd.read_parquet("brick/yearly_obs36_processed/6_20170101_hlact_studies.parquet")
    df_18 = pd.read_parquet("brick/yearly_obs36_processed/7_20180101_hlact_studies.parquet")
    df_19 = pd.read_parquet("brick/yearly_obs36_processed/8_20190101_hlact_studies.parquet")
    df_20 = pd.read_parquet("brick/yearly_obs36_processed/9_20200101_hlact_studies.parquet")
    df_21 = pd.read_parquet("brick/yearly_obs36_processed/10_20210101_hlact_studies.parquet")
    df_22 = pd.read_parquet("brick/yearly_obs36_processed/11_20220101_hlact_studies.parquet")
    df_23 = pd.read_parquet("brick/yearly_obs36_processed/12_20230101_hlact_studies.parquet")
    df_24 = pd.read_parquet("brick/yearly_obs36_processed/13_20240101_hlact_studies.parquet")

    all_dfs = [df_12, df_13, df_14, df_15, df_16, 
               df_17, df_18, df_19, df_20, df_21, df_22, df_23, df_24]
    all_years = [ 2012, 2013, 2014, 2015, 2016, 2017, 2018, 2019, 2020, 2021, 2022, 2023, 2024]
    
    for df, year in zip(all_dfs, all_years):
        df['year'] = int(year)
        
    df = pd.concat(all_dfs)    
    
    df = utils.process_months_to_report(df)
    
    
    col = 'rf_months_to_report'
    # col = 'schema1.months_to_report_results'
    d_means = df.groupby('year')[col].mean().to_dict()
    d_medians = df.groupby('year')[col].median().to_dict()
    d_25 = df.groupby('year')[col].quantile(.25).to_dict()
    d_75 = df.groupby('year')[col].quantile(.75).to_dict()
    d_10 = df.groupby('year')[col].quantile(.10).to_dict()
    d_90 = df.groupby('year')[col].quantile(.90).to_dict()
    
    years = list(d_means.keys())
    means = list(d_means.values())
    medians = list(d_medians.values())
    q25s = list(d_25.values())
    q75s = list(d_75.values())
    q10s = list(d_10.values())
    q90s = list(d_90.values())

    
    df['start_year'] = df['year'] - 3
    start_years = [year - 3 for year in years]
    
    
    p = bokeh.plotting.figure(
        output_backend='svg',
        height=400, width=600, y_range=(0, 52),
        x_axis_label='Start year', y_axis_label='months to report',
        title='*Of those reported* within 36 months, quantiles of months to report',
    )
    
    color_means, color_medians = 'indianred', '#232323'
    color_25 = '#cdcdcd'
    
    # p.circle(x=years, y=means, legend_label='mean', color=color_means)
    # p.line(x=years, y=means, legend_label='mean', color=color_means)
    
    p.multi_line(xs=[(x, x) for x in start_years], 
                 ys=[(q25, q75) for q25, q75 in zip(q10s, q90s)],
                 legend_label='10th & 90th percentile', 
                 color = color_25, width=1.5, alpha=1.0, line_cap='square')
    
    p.multi_line(xs=[(x, x) for x in start_years], 
                 ys=[(q25, q75) for q25, q75 in zip(q25s, q75s)],
                 legend_label='25 & 75th percentile', 
                 color = color_25, width=15, alpha=1.0)
    
    
    intervention_pt = 2017 + 4/12 # April  (this draws the vertical line)
    p.line((intervention_pt, intervention_pt), (-5, 90), color='maroon', alpha=0.3, width=2, 
           legend_label='Final Rule in effect April 2017 '
          )
    
    p.circle(x=start_years, y=medians, 
             legend_label='median', 
             color=color_medians, size=7)
    p.line(x=start_years, y=medians, 
           legend_label='median', 
           color=color_medians, line_width=1, line_dash='dotted')
    
    p.xaxis.ticker = [2008, 2009, 2010, 2011, 2012, 2013, 2014, 2015, 2016, 2017, 
                      2018, 2019, 2020, 2021, 2022, 2023]
    
    p.yaxis.ticker = [0, 12, 24, 36, 48, 60, 72, 84, 96]
    # p.yaxis.ticker = np.arange(0, 100)
    
    p.xgrid.grid_line_color = None
    p_boxplot = p


    # Create barchart of volume of those reporting
    d_p_report = df.groupby('year')['rf_months_to_report'].apply(
        lambda x: 1- x.isnull().sum()/len(x)).to_dict()
    years = d_p_report.keys()
    p_report = d_p_report.values()
    
    p = bokeh.plotting.figure(
        output_backend='svg',
        height=300, width=500, y_range=(-0.05, 1),
        x_axis_label='Cutoff year', y_axis_label='months to report',
        title='% Reporting Results within 36 months',
    )
    color_means, color_medians = 'indianred', 'darkblue'
    color_25 = '#a0a0a0'
    
    p.multi_line(xs=[(x, x) for x in years], 
                 ys=[(0, p) for p in zip(p_report)],
                 legend_label='% reported results within 36 months', 
                 color = color_25, width=15, alpha=0.5)
    
    p.xaxis.ticker = [2011, 2012, 2013, 2014, 2015, 2016, 2017, 
                      2018, 2019, 2020, 2021, 2022, 2023, 2024]
    
    p.yaxis.ticker = [0, 0.2, 0.4, 0.6, 0.8, 1.0]
    
    p_barchart = p

    return p_boxplot, p_barchart



def permutation_test(n_pre, N_pre, n_post, N_post, N_reps=50_000):
    def create_array(n, N):
        return np.hstack([np.ones(n), np.zeros(N-n)])
    
    def test_statistic(a, b):
        return np.mean(b) - np.mean(a)
    
    # Permutation Replicate
    # This assumes two samples are identically distributed
    def draw_perm_sample(arr_pre, arr_post):
        concat_data = np.concatenate((arr_pre, arr_post))
        np.random.shuffle(concat_data)
        return concat_data[:len(arr_pre)], concat_data[len(arr_pre):]
    
    def get_p_value(n_pre, N_pre, n_post, N_post, N_reps = 10_000):
        arr_pre  = create_array(n_pre, N_pre) # pre
        arr_post = create_array(n_post, N_post) # post
        
        out = np.empty(N_reps)
        for i in tqdm(range(N_reps)):
            sim_pre, sim_post = draw_perm_sample(arr_pre, arr_post)
            p_pre, p_post = sum(sim_pre)/len(sim_pre), sum(sim_post)/len(sim_post)
            sim_diff = p_post - p_pre
            out[i] = sim_diff
    
        diff_orig = (n_post/N_post) - (n_pre/N_pre)
        p_value = np.sum(out >= diff_orig) / len(out)
        print('p-value: ', p_value)
        return diff_orig, p_value
        
    diff_orig, p_value = get_p_value(n_pre, N_pre, n_post, N_post, N_reps=N_reps)
    return diff_orig, p_value
    
    
# PERMUTATION TEST RESULTS
def permutation_test_overall(df_pre, df_post, N_reps=50_000):
    q_pre = df_pre['rf_months_to_report'].values
    q_post = df_post['rf_months_to_report'].values
    
    # Pre: 
    n_pre_12 = len(df_pre.loc[df_pre['rf_months_to_report'].apply(lambda x: x<=12+1/30.5)])
    n_pre_36 = len(df_pre.loc[df_pre['rf_months_to_report'].apply(lambda x: x<=36+1/30.5)])
    N_pre = len(q_pre)
    p_pre_12 = n_pre_12/N_pre
    p_pre_36 = n_pre_36/N_pre
    
    # Post: 
    n_post_12 = len(df_post.loc[df_post['rf_months_to_report'].apply(lambda x: x<=12+1/30.5)])
    n_post_36 = len(df_post.loc[df_post['rf_months_to_report'].apply(lambda x: x<=36+1/30.5)])
    N_post = len(q_post)
    p_post_12 = n_post_12/N_post
    p_post_36 = n_post_36/N_post
    
    # print(n_pre_12, n_pre_36, n_post_12, n_post_36)
    
    # print(N_pre, N_post)
    # print(p_pre_12, p_post_12, '\n',
    #       p_pre_36, p_post_36)
    

    d12, p12 = permutation_test(n_pre_12, N_pre, n_post_12, N_post, N_reps=N_reps)
    d36, p36 = permutation_test(n_pre_36, N_pre, n_post_36, N_post, N_reps=N_reps)
    results = pd.DataFrame({
        'name':['diff_orig_12mo', 'pvalue_12mo', 'diff_orig_36mo', 'pvalue_36mo'],
        'value':[d12, p12, d36, p36]
    })
    return results
    


def permutation_test_subgroup(row, N_reps=50_000):
    n_pre, N_pre, n_post, N_post = row.n_pre, row.N_pre, row.n_post, row.N_post
    diff_orig, p_value = permutation_test(n_pre, N_pre, n_post, N_post, N_reps=N_reps)
    return p_value


def table_pvalues_subgroup_save(df_prepost_12, df_prepost_36):
    table = df_prepost_12[['group', 'subgroup', 'rate_pre', 'rate_post', 'p_value']].rename(
        columns={'rate_pre':'rate_pre_12mo',
                 'rate_post':'rate_post_12mo',
                 'p_value':'p_value_12mo'}).merge(
        df_prepost_36[['group', 'subgroup', 'rate_pre', 'rate_post', 'p_value']].rename(
        columns={'rate_pre':'rate_pre_36mo',
                 'rate_post':'rate_post_36mo',
                 'p_value':'p_value_36mo'}))
    return table

# RUN MAIN
if __name__ == '__main__':
    output_dir = Path('figtab/plotter_py')
    output_dir.mkdir(parents=True, exist_ok=True)
    # Get dataframes
    path_pre_processed = "brick/rule-effective-date_processed/datebefore_hlact_studies.parquet"
    path_post_processed = "brick/rule-effective-date_processed/dateafter_hlact_studies.parquet"
    df_pre, df_post, df_overall, df_prepost_12, df_prepost_36 = utils.get_dataframes(
        path_pre_processed, 
        path_post_processed
    )

    
    # Create and save 
    # - table_rates_overall.csv,
    # - table_rates_subgroup.csv, 
    # - table_composition_subgroup.csv

    print(f"\n Creating and saving in {output_dir}")
    print("- table_rates_overall.csv")
    print("- table_rates_subgroup.csv")
    print("- table_composition_subgroup.csv \n")
    
    table_rates_overall_save = table_rates_overall(df_overall, df_pre, df_post)
    table_rates_overall_save.to_csv(output_dir / "table_rates_overall.csv", index=False)

    table_rates_subgroup_save = table_rates_subgroup(df_prepost_12, df_prepost_36)
    table_rates_subgroup_save.to_csv(output_dir / "table_rates_subgroup.csv", index=False) 

    # only needs one of them df_prepost_12, redundant columns in both 12 and 36
    table_composition_subgroup_save = table_composition_subgroup(df_prepost_12) 
    table_composition_subgroup_save.to_csv(output_dir / "table_composition_subgroup.csv", index=False) 



    
    # Create and save 
    # - p_lollipop_12.svg : shows subgroups pre/post rr12mo on lollipop chart
    # - p_lollipop_36.svg : shows subgroups pre/post rr36mo on lollipop chart
    # - p_boxplot_yearly.svg  : shows boxplots of time to report of those who report within 36mo
    # - p_barchart_yearly.svg : shows proportion of those who report within 36mo

    print(f"\n Creating and saving in {output_dir}")
    print("- p_lollipop_12.svg and _36.svg")
    print("- p_boxplot_yearly.svg and p_barchart_yearly.svg \n")
    
    p_lollipop_12, p_lollipop_36 = plot_lollipop(df_prepost_12, df_prepost_36)

    bokeh.io.show(bokeh.layouts.row(p_lollipop_12, p_lollipop_36))
    bokeh.io.export_svg(p_lollipop_12, filename=output_dir / 'p_lollipop_12.svg')
    bokeh.io.export_svg(p_lollipop_36, filename=output_dir / 'p_lollipop_36.svg')

    p_boxplot_yearly, p_barchart_yearly = plot_boxplot_yearly()
    bokeh.io.show(bokeh.layouts.column(p_boxplot_yearly, p_barchart_yearly))
    bokeh.io.export_svg(p_boxplot_yearly, filename=output_dir / 'p_boxplot_yearly.svg')
    bokeh.io.export_svg(p_barchart_yearly, filename=output_dir / 'p_barchart_yearly.svg')



    
    # Create and save 
    # - permutation_results.csv
    output_permutation_path = output_dir / "permutation_results.csv"
    print(f"\n Creating and saving {output_permutation_path}...")
    
    N_reps = 50_000
    permutation_results = permutation_test_overall(df_pre, df_post, N_reps=N_reps)
    permutation_results.to_csv(output_permutation_path, index=False) 
    
    df_prepost_12['p_value'] = df_prepost_12.apply(permutation_test_subgroup, axis=1, args=(N_reps,))
    df_prepost_36['p_value'] = df_prepost_36.apply(permutation_test_subgroup, axis=1, args=(N_reps,))
    
    permutation_results_subgroup = table_pvalues_subgroup_save(df_prepost_12, df_prepost_36)
    permutation_results_subgroup.to_csv( output_dir / "permutation_results_subgroup.csv", index=False)
    

    pass










