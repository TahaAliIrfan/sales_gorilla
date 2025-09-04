import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["teamOverview", "userPerformance", "communicationAnalytics", "dealAnalytics", "topPerformers", "additionalAnalytics"]
  static values = { 
    filterRange: String,
    startDate: String,
    endDate: String,
    userId: String 
  }

  connect() {
    this.currentFilters = {
      filter_range: this.filterRangeValue || '30',
      start_date: this.startDateValue || '',
      end_date: this.endDateValue || '',
      user_id: this.userIdValue || ''
    }
    
    // Load sections with a small delay to allow DOM to settle
    setTimeout(() => {
      this.loadAllSections()
    }, 100)
  }

  showGlobalLoading() {
    document.getElementById('global-loading').classList.remove('hidden')
  }

  hideGlobalLoading() {
    document.getElementById('global-loading').classList.add('hidden')
  }

  async loadSection(endpoint, target, renderMethod) {
    try {
      const params = new URLSearchParams(this.currentFilters)
      const response = await fetch(`${endpoint}?${params}`, {
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })
      
      if (!response.ok) throw new Error(`HTTP error! status: ${response.status}`)
      
      const data = await response.json()
      this[renderMethod](data, target)
    } catch (error) {
      console.error(`Error loading ${endpoint}:`, error)
      target.innerHTML = '<div class="text-center text-red-500 py-4">Error loading data. Please refresh the page.</div>'
    }
  }

  renderTeamOverview(data, target) {
    target.innerHTML = `
      <div class="bg-white overflow-hidden shadow rounded-lg">
        <div class="p-5">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <svg class="h-6 w-6 text-blue-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 919.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
              </svg>
            </div>
            <div class="ml-5 w-0 flex-1">
              <dl>
                <dt class="text-sm font-medium text-gray-500 truncate">Total Users</dt>
                <dd class="text-2xl font-semibold text-gray-900">${data.total_users}</dd>
              </dl>
            </div>
          </div>
        </div>
      </div>
      <div class="bg-white overflow-hidden shadow rounded-lg">
        <div class="p-5">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <svg class="h-6 w-6 text-green-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z" />
              </svg>
            </div>
            <div class="ml-5 w-0 flex-1">
              <dl>
                <dt class="text-sm font-medium text-gray-500 truncate">Active Users</dt>
                <dd class="text-2xl font-semibold text-gray-900">${data.active_users}</dd>
              </dl>
            </div>
          </div>
        </div>
      </div>
      <div class="bg-white overflow-hidden shadow rounded-lg">
        <div class="p-5">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <svg class="h-6 w-6 text-purple-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            </div>
            <div class="ml-5 w-0 flex-1">
              <dl>
                <dt class="text-sm font-medium text-gray-500 truncate">Total Revenue</dt>
                <dd class="text-2xl font-semibold text-gray-900">$${(data.total_revenue || 0).toLocaleString()}</dd>
              </dl>
            </div>
          </div>
        </div>
      </div>
      <div class="bg-white overflow-hidden shadow rounded-lg">
        <div class="p-5">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <svg class="h-6 w-6 text-yellow-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
              </svg>
            </div>
            <div class="ml-5 w-0 flex-1">
              <dl>
                <dt class="text-sm font-medium text-gray-500 truncate">Total Deals</dt>
                <dd class="text-2xl font-semibold text-gray-900">${data.total_deals}</dd>
              </dl>
            </div>
          </div>
        </div>
      </div>
      <div class="bg-white overflow-hidden shadow rounded-lg">
        <div class="p-5">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <svg class="h-6 w-6 text-red-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 12l3-3 3 3 4-4M8 21l4-4 4 4M3 4h18M4 4h16v12a1 1 0 01-1 1H5a1 1 0 01-1-1V4z" />
              </svg>
            </div>
            <div class="ml-5 w-0 flex-1">
              <dl>
                <dt class="text-sm font-medium text-gray-500 truncate">Conversion Rate</dt>
                <dd class="text-2xl font-semibold text-gray-900">${data.conversion_rate}%</dd>
              </dl>
            </div>
          </div>
        </div>
      </div>
    `
    
    // Render top performers if available
    if (data.top_performers && this.hasTopPerformersTarget) {
      this.renderTopPerformers(data.top_performers)
    }
  }

  renderTopPerformers(topPerformers) {
    if (!this.hasTopPerformersTarget) return
    
    let performerCards = ''
    topPerformers.forEach((performer, index) => {
      performerCards += `
        <div class="relative bg-gradient-to-r from-blue-500 to-purple-600 rounded-lg p-4 text-white">
          <div class="flex items-center justify-between">
            <div>
              <div class="text-lg font-semibold">${performer.name || 'Unknown User'}</div>
              <div class="text-sm opacity-90">Score: ${performer.score}/100</div>
              <div class="text-sm opacity-90">Deals Won: ${performer.deals_won}</div>
              <div class="text-sm opacity-90">Revenue: $${(performer.revenue || 0).toLocaleString()}</div>
            </div>
            <div class="text-3xl font-bold opacity-50">#${index + 1}</div>
          </div>
        </div>
      `
    })
    
    const cardContainer = this.topPerformersTarget.querySelector('.px-4')
    cardContainer.innerHTML = `
      <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
        ${performerCards}
      </div>
    `
  }

  renderUserPerformance(data, target) {
    let tableRows = ''
    
    data.forEach(user => {
      const roleClass = {
        'admin': 'bg-red-100 text-red-800',
        'manager': 'bg-yellow-100 text-yellow-800', 
        'associate': 'bg-green-100 text-green-800'
      }[user.role] || 'bg-gray-100 text-gray-800'
      
      const initials = (user.name || 'N/A').split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2)
      
      tableRows += `
        <tr class="hover:bg-gray-50">
          <td class="px-6 py-4 whitespace-nowrap">
            <div class="flex items-center">
              <div class="flex-shrink-0 h-10 w-10">
                <div class="h-10 w-10 rounded-full bg-blue-100 flex items-center justify-center">
                  <span class="text-sm font-medium text-blue-800">${initials}</span>
                </div>
              </div>
              <div class="ml-4">
                <div class="text-sm font-medium text-gray-900">${user.name || 'Unknown User'}</div>
                <div class="text-sm text-gray-500">${user.email || ''}</div>
              </div>
            </div>
          </td>
          <td class="px-6 py-4 whitespace-nowrap">
            <span class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full ${roleClass}">
              ${user.role}
            </span>
          </td>
          <td class="px-6 py-4 whitespace-nowrap">
            <div class="flex items-center">
              <div class="text-sm font-medium text-gray-900">${user.performance_score}/100</div>
              <div class="ml-2 w-16 bg-gray-200 rounded-full h-2">
                <div class="bg-blue-600 h-2 rounded-full" style="width: ${user.performance_score}%"></div>
              </div>
            </div>
          </td>
          <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
            <div class="space-y-1">
              <div>Calls: <span class="font-medium">${user.daily_metrics.today.calls}</span></div>
              <div>Tasks: <span class="font-medium">${user.daily_metrics.today.tasks_completed}</span></div>
              <div>Deals: <span class="font-medium">${user.daily_metrics.today.deals_created}</span></div>
            </div>
          </td>
          <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
            <div class="space-y-1">
              <div>Calls: <span class="font-medium">${user.weekly_metrics.this_week.calls}</span></div>
              <div>Success: <span class="font-medium">${user.weekly_metrics.this_week.successful_calls}</span></div>
              <div>Deals Won: <span class="font-medium">${user.weekly_metrics.this_week.deals_won}</span></div>
              <div>Revenue: <span class="font-medium">$${(user.weekly_metrics.this_week.revenue_generated || 0).toLocaleString()}</span></div>
            </div>
          </td>
          <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
            <div class="space-y-1">
              <div>Calls: <span class="font-medium">${user.monthly_metrics.this_month.calls}</span></div>
              <div>Success: <span class="font-medium">${user.monthly_metrics.this_month.successful_calls}</span></div>
              <div>Deals Won: <span class="font-medium">${user.monthly_metrics.this_month.deals_won}</span></div>
              <div>Revenue: <span class="font-medium">$${(user.monthly_metrics.this_month.revenue_generated || 0).toLocaleString()}</span></div>
              <div>Converted: <span class="font-medium">${user.monthly_metrics.this_month.customers_converted}</span></div>
            </div>
          </td>
        </tr>
      `
    })
    
    const tableContainer = target.querySelector('.overflow-x-auto')
    tableContainer.innerHTML = `
      <table class="min-w-full divide-y divide-gray-200">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">User</th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Role</th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Performance Score</th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Today</th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">This Week</th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">This Month</th>
          </tr>
        </thead>
        <tbody class="bg-white divide-y divide-gray-200">
          ${tableRows}
        </tbody>
      </table>
    `
  }

  renderCommunicationAnalytics(data, target) {
    let tableRows = ''
    
    Object.entries(data).forEach(([userId, userData]) => {
      const successRate = userData.calls_made > 0 ? 
        ((userData.successful_calls / userData.calls_made) * 100).toFixed(1) : 0
      
      tableRows += `
        <tr class="hover:bg-gray-50">
          <td class="px-6 py-4 whitespace-nowrap">
            <div class="text-sm font-medium text-gray-900">${userData.name || 'Unknown User'}</div>
          </td>
          <td class="px-6 py-4 whitespace-nowrap">
            <div class="text-sm text-gray-900 font-medium">${userData.calls_made}</div>
          </td>
          <td class="px-6 py-4 whitespace-nowrap">
            <div class="text-sm text-gray-900 font-medium">${userData.successful_calls}</div>
          </td>
          <td class="px-6 py-4 whitespace-nowrap">
            <div class="flex items-center">
              <div class="text-sm font-medium text-gray-900">${successRate}%</div>
              <div class="ml-2 w-16 bg-gray-200 rounded-full h-2">
                <div class="bg-green-600 h-2 rounded-full" style="width: ${Math.min(successRate, 100)}%"></div>
              </div>
            </div>
          </td>
          <td class="px-6 py-4 whitespace-nowrap">
            <div class="text-sm text-gray-900 font-medium">${userData.customers_contacted}</div>
          </td>
          <td class="px-6 py-4 whitespace-nowrap">
            <div class="text-sm text-gray-900 font-medium">${userData.deals_created}</div>
          </td>
          <td class="px-6 py-4 whitespace-nowrap">
            <div class="text-sm text-gray-900 font-medium">${userData.deals_won}</div>
          </td>
        </tr>
      `
    })
    
    const tableContainer = target.querySelector('.overflow-x-auto')
    tableContainer.innerHTML = `
      <table class="min-w-full divide-y divide-gray-200">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">User</th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Total Calls</th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Successful Calls</th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Success Rate</th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Customers Contacted</th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Deals Created</th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Deals Won</th>
          </tr>
        </thead>
        <tbody class="bg-white divide-y divide-gray-200">
          ${tableRows}
        </tbody>
      </table>
    `
  }

  renderDealAnalytics(data, target) {
    let stageRows = ''
    if (data.deals_by_stage && Object.keys(data.deals_by_stage).length > 0) {
      const totalDeals = Object.values(data.deals_by_stage).reduce((sum, count) => sum + count, 0)
      
      Object.entries(data.deals_by_stage).forEach(([stageName, count]) => {
        const percentage = totalDeals > 0 ? ((count / totalDeals) * 100).toFixed(1) : 0
        stageRows += `
          <div class="flex items-center justify-between">
            <div class="text-sm font-medium text-gray-700">${stageName}</div>
            <div class="flex items-center">
              <span class="text-sm font-medium text-gray-900 mr-3">${count}</span>
              <div class="w-16 bg-gray-200 rounded-full h-2">
                <div class="bg-blue-600 h-2 rounded-full" style="width: ${percentage}%"></div>
              </div>
            </div>
          </div>
        `
      })
    } else {
      stageRows = '<div class="text-center text-gray-500">No deals found for the selected period</div>'
    }
    
    let userRows = ''
    if (data.deals_by_user && Object.keys(data.deals_by_user).length > 0) {
      const totalUserDeals = Object.values(data.deals_by_user).reduce((sum, count) => sum + count, 0)
      const sortedUsers = Object.entries(data.deals_by_user)
        .sort(([,a], [,b]) => b - a)
        .slice(0, 10)
      
      sortedUsers.forEach(([userName, count]) => {
        const percentage = totalUserDeals > 0 ? ((count / totalUserDeals) * 100).toFixed(1) : 0
        userRows += `
          <div class="flex items-center justify-between">
            <div class="text-sm font-medium text-gray-700">${userName}</div>
            <div class="flex items-center">
              <span class="text-sm font-medium text-gray-900 mr-3">${count}</span>
              <div class="w-16 bg-gray-200 rounded-full h-2">
                <div class="bg-purple-600 h-2 rounded-full" style="width: ${percentage}%"></div>
              </div>
            </div>
          </div>
        `
      })
    } else {
      userRows = '<div class="text-center text-gray-500">No deals found for the selected period</div>'
    }
    
    target.innerHTML = `
      <div class="bg-white shadow rounded-lg">
        <div class="px-4 py-5 sm:px-6 border-b border-gray-200">
          <h3 class="text-lg font-medium leading-6 text-gray-900">Deals by Stage</h3>
        </div>
        <div class="px-4 py-5 sm:p-6">
          <div class="space-y-3">
            ${stageRows}
          </div>
        </div>
      </div>
      <div class="bg-white shadow rounded-lg">
        <div class="px-4 py-5 sm:px-6 border-b border-gray-200">
          <h3 class="text-lg font-medium leading-6 text-gray-900">Deals by User</h3>
        </div>
        <div class="px-4 py-5 sm:p-6">
          <div class="space-y-3">
            ${userRows}
          </div>
        </div>
      </div>
    `

    // Update additional analytics if target exists
    if (this.hasAdditionalAnalyticsTarget) {
      this.additionalAnalyticsTarget.innerHTML = `
        <div class="bg-white overflow-hidden shadow rounded-lg">
          <div class="p-5">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <svg class="h-6 w-6 text-green-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
              </div>
              <div class="ml-5 w-0 flex-1">
                <dl>
                  <dt class="text-sm font-medium text-gray-500 truncate">Average Deal Size</dt>
                  <dd class="text-2xl font-semibold text-gray-900">$${(data.average_deal_size || 0).toLocaleString()}</dd>
                </dl>
              </div>
            </div>
          </div>
        </div>
        <div class="bg-white overflow-hidden shadow rounded-lg">
          <div class="p-5">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <svg class="h-6 w-6 text-blue-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z" />
                </svg>
              </div>
              <div class="ml-5 w-0 flex-1">
                <dl>
                  <dt class="text-sm font-medium text-gray-500 truncate">Deal Velocity</dt>
                  <dd class="text-2xl font-semibold text-gray-900">${data.deal_velocity} days</dd>
                </dl>
              </div>
            </div>
          </div>
        </div>
        <div class="bg-white overflow-hidden shadow rounded-lg">
          <div class="p-5">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <svg class="h-6 w-6 text-yellow-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
                </svg>
              </div>
              <div class="ml-5 w-0 flex-1">
                <dl>
                  <dt class="text-sm font-medium text-gray-500 truncate">Pipeline Value</dt>
                  <dd class="text-2xl font-semibold text-gray-900">Pipeline</dd>
                </dl>
              </div>
            </div>
          </div>
        </div>
      `
    }
  }

  async loadAllSections() {
    try {
      // Load team overview first (includes top performers)
      await this.loadSection('/dashboard/team_overview', this.teamOverviewTarget, 'renderTeamOverview')
      
      // Load other sections in parallel
      const loadPromises = [
        this.loadSection('/dashboard/user_performance', this.userPerformanceTarget, 'renderUserPerformance'),
        this.loadSection('/dashboard/communication_analytics', this.communicationAnalyticsTarget, 'renderCommunicationAnalytics'),
        this.loadSection('/dashboard/deal_analytics', this.dealAnalyticsTarget, 'renderDealAnalytics')
      ]
      
      await Promise.allSettled(loadPromises)
    } catch (error) {
      console.error('Error loading dashboard sections:', error)
    }
  }

  updateFilters(event) {
    event.preventDefault()
    
    const formData = new FormData(event.target)
    const newFilters = {}
    
    for (let [key, value] of formData.entries()) {
      newFilters[key] = value
    }
    
    this.currentFilters = { ...this.currentFilters, ...newFilters }
    this.showGlobalLoading()
    
    this.loadAllSections().finally(() => {
      this.hideGlobalLoading()
    })
  }

  clearFilters(event) {
    event.preventDefault()
    
    // Reset form
    const form = this.element.querySelector('#dashboard-filters')
    if (form) form.reset()
    
    // Reset filters to defaults
    this.currentFilters = {
      filter_range: '30',
      start_date: '',
      end_date: '',
      user_id: ''
    }
    
    this.showGlobalLoading()
    this.loadAllSections().finally(() => {
      this.hideGlobalLoading()
    })
  }

  toggleCustomDates() {
    const select = this.element.querySelector('select[name="filter_range"]')
    const customDates = this.element.querySelector('#custom-dates')
    
    if (select && customDates) {
      if (select.value === 'custom') {
        customDates.style.display = 'block'
      } else {
        customDates.style.display = 'none'
      }
    }
  }
}