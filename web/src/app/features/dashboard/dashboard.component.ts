import { Component, inject, OnInit } from '@angular/core';

import { Router } from '@angular/router';
import { AuthService } from '../../core/services/auth.service';

@Component({
  selector: 'app-dashboard',
  standalone: true,
  imports: [],
  template: `
    <div class="min-h-screen bg-[#f8fafc] flex flex-col items-center justify-center p-6 font-sans">
      <div class="w-8 h-8 rounded-full border-2 border-slate-300 border-t-slate-800 animate-spin mb-3"></div>
      <p class="text-sm font-medium text-slate-600">Redirigiendo a tu panel...</p>
    </div>
  `
})
export class DashboardComponent implements OnInit {
  private readonly authService = inject(AuthService);
  private readonly router = inject(Router);

  ngOnInit(): void {
    const route = this.authService.getDashboardRoute();
    this.router.navigate([route]);
  }
}


